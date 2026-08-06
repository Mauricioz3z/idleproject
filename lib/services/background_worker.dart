import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

import '../core/rng/rng_stream.dart';
import '../data/repositories/content_repository_impl.dart';
import '../data/repositories/hive_save_repository.dart';
import '../domain/engines/combat_engine.dart';
import '../domain/engines/offline_simulator.dart';
import '../domain/engines/state_projector.dart';
import '../domain/engines/wave_director.dart';
import '../domain/entities/save_state.dart';
import '../main.dart' show Boxes;
import 'background_service.dart';
import 'home_widget_service.dart';
import 'notification_service.dart';

/// Ponto de entrada das tarefas do WorkManager.
///
/// Roda num isolate próprio, sem acesso ao estado do app. Por isso tudo aqui é
/// recarregado do zero — e por isso nada aqui **grava** save: a única escritora
/// continua sendo a sessão do jogador, o que elimina a corrida de CEN-M10-E03.
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      final state = await _loadSave();
      if (state == null) return true; // sem save, nada a projetar

      switch (task) {
        case BackgroundTasks.refreshWidget:
          await BackgroundJobs.refreshWidget(state);
        case BackgroundTasks.detectRareEvents:
          await BackgroundJobs.detectRareEvents(state);
      }
      return true;
    } on Object {
      // Falha em segundo plano nunca pode derrubar nada visível: o estado
      // correto é recuperado pelo cálculo offline na reabertura (CEN-M11-E02).
      return true;
    }
  });
}

Future<SaveState?> _loadSave() async {
  await Hive.initFlutter();
  final meta = await Hive.openBox<dynamic>(Boxes.meta);
  final account = await Hive.openBox<dynamic>(Boxes.account);
  return HiveSaveRepository(metaBox: meta, saveBox: account).load();
}

/// As tarefas em si, separadas do despachante para poderem ser testadas.
abstract final class BackgroundJobs {
  /// Chave do último item raro já notificado. Vive no armazenamento do widget,
  /// não no save: é estado de notificação, não progresso de jogo.
  static const String lastNotifiedRareKey = 'w_lastNotifiedRareId';
  static const String inventoryFullNotifiedKey = 'w_inventoryFullNotified';

  /// `refresh_widget`: projeta e reescreve o payload. Não roda combate.
  static Future<void> refreshWidget(SaveState state) async {
    final projection = StateProjector.project(
      state: state,
      now: DateTime.now(),
    );
    await const HomeWidgetService().publish(projection);
  }

  /// `detect_rare_events`: descobre o que a ausência **vai** conceder e avisa.
  ///
  /// O truque que torna isto possível sem rodar combate de verdade: a simulação
  /// é pura e determinística. Rodá-la aqui e **descartar** o estado não altera
  /// nada, e quando o jogador reabrir, a mesma simulação, a partir do mesmo save
  /// e da mesma semente, produzirá exatamente os mesmos itens. A notificação
  /// portanto anuncia o que o jogador de fato vai receber — e não uma
  /// estimativa que o resumo depois desmente.
  ///
  /// Continua valendo §8 de `specification.md`: nenhum combate real acontece em
  /// segundo plano, e nenhum estado é gravado.
  static Future<void> detectRareEvents(SaveState state) async {
    final content = await _loadContent();
    if (content == null) return;

    final simulation = const OfflineSimulator().simulate(
      state: state,
      now: DateTime.now(),
      combat: CombatEngine(rng: RngStream(seed: state.account.rngSeed)),
      waves: WaveDirector(templates: content.monsters()),
      classes: content.heroClasses(),
    );

    final notifications = NotificationService();
    await notifications.initialize();

    final rare = simulation.report.rareHighlights;
    if (rare.isNotEmpty) {
      final latest = rare.last;
      final alreadyNotified = await HomeWidget.getWidgetData<String>(
        lastNotifiedRareKey,
        defaultValue: '',
      );
      if (alreadyNotified != latest.id) {
        await notifications.notifyRareLoot(
          rarityId: latest.rarity.id,
          itemLabel: '${latest.type.id} iLv${latest.itemLevel}',
        );
        await HomeWidget.saveWidgetData<String>(lastNotifiedRareKey, latest.id);
      }
    }

    if (simulation.report.inventoryBecameFull) {
      final already = await HomeWidget.getWidgetData<bool>(
        inventoryFullNotifiedKey,
        defaultValue: false,
      );
      if (already != true) {
        await notifications.notifyInventoryFull();
        await HomeWidget.saveWidgetData<bool>(inventoryFullNotifiedKey, true);
      }
    } else {
      await HomeWidget.saveWidgetData<bool>(inventoryFullNotifiedKey, false);
    }
  }

  static Future<JsonContentRepository?> _loadContent() async {
    try {
      return JsonContentRepository.fromJson(
        heroClassesJson: await rootBundle.loadString(
          'assets/content/hero_classes.json',
        ),
        monstersJson: await rootBundle.loadString(
          'assets/content/monsters.json',
        ),
        runeTreeJson: await rootBundle.loadString(
          'assets/content/rune_tree.json',
        ),
        requireFullRuneTree: false,
      );
    } on Object {
      return null;
    }
  }
}
