import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/repositories/content_repository_impl.dart';
import 'data/repositories/hive_save_repository.dart';
import 'domain/engines/state_projector.dart';
import 'presentation/providers/combat_providers.dart';
import 'presentation/providers/notification_providers.dart';
import 'presentation/providers/offline_providers.dart';
import 'presentation/providers/rune_providers.dart';
import 'services/background_worker.dart';
import 'services/home_widget_service.dart';
import 'services/save_scheduler.dart';

/// Nomes dos boxes Hive, conforme contracts/persistence-save-schema.md.
///
/// A separação existe para que o auto-save de 30 s grave só o que mudou, em vez
/// de reserializar tudo.
abstract final class Boxes {
  static const String meta = 'meta';
  static const String account = 'account';
  static const String heroes = 'heroes';
  static const String inventory = 'inventory';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox<dynamic>(Boxes.meta),
    Hive.openBox<dynamic>(Boxes.account),
    Hive.openBox<dynamic>(Boxes.heroes),
    Hive.openBox<dynamic>(Boxes.inventory),
  ]);

  final content = JsonContentRepository.fromJson(
    heroClassesJson: await rootBundle.loadString(
      'assets/content/hero_classes.json',
    ),
    monstersJson: await rootBundle.loadString('assets/content/monsters.json'),
    runeTreeJson: await rootBundle.loadString('assets/content/rune_tree.json'),
    // A árvore foi autorada em T123: o mínimo de 200 nós volta a ser exigido
    // no boot. Um conteúdo incompleto agora é erro de build, não um jogo com
    // metade da progressão faltando.
  );

  final repository = HiveSaveRepository(
    metaBox: Hive.box<dynamic>(Boxes.meta),
    saveBox: Hive.box<dynamic>(Boxes.account),
    knownRuneNodeIds: {for (final n in content.runeTree().nodes) n.id},
  );

  // A semente vem do save quando existe: o fluxo determinístico precisa
  // continuar de onde parou, senão reabrir o app re-sortearia todo o loot
  // (research.md R5).
  final existing = await repository.load();
  final seed =
      existing?.account.rngSeed ?? DateTime.now().millisecondsSinceEpoch;

  final container = ProviderContainer(
    overrides: [
      combatDependenciesProvider.overrideWithValue(
        CombatDependencies(
          classes: content.heroClasses(),
          monsterTemplates: content.monsters(),
          seed: seed,
        ),
      ),
      saveRepositoryProvider.overrideWithValue(repository),
      runeTreeProvider.overrideWithValue(content.runeTree()),
    ],
  );

  final clock = container.read(clockProvider);
  final scheduler = SaveScheduler(
    repository: repository,
    clock: clock,
    snapshot: () => container
        .read(combatControllerProvider.notifier)
        .snapshot(
          now: clock.now(),
          monotonicMillis: clock.monotonicMillis(),
        ),
  )..start();

  // M11: notificações, widget e tarefas periódicas. Nenhuma delas é
  // pré-requisito de progresso — se qualquer uma falhar, o jogo abre igual
  // (SC-M11-04, CEN-M11-E01).
  unawaited(_startPlatformServices(container));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _PlatformBridge(
        scheduler: scheduler,
        container: container,
        child: const PixelIdleQuestApp(),
      ),
    ),
  );
}

Future<void> _startPlatformServices(ProviderContainer container) async {
  try {
    final notifications = container.read(notificationServiceProvider);
    await notifications.initialize();
    await container
        .read(notificationSettingsProvider.notifier)
        .requestPermission();

    final background = container.read(backgroundServiceProvider)
      ..configureForegroundTask();
    await background.start(callbackDispatcher: backgroundCallbackDispatcher);
  } on Object {
    // Plataforma indisponível ou permissão negada: seguir sem widget e sem
    // notificação é comportamento previsto, não erro.
  }
}

/// Ponte com a plataforma: auto-save, payload do widget e notificação
/// persistente.
///
/// Fica fora de [PixelIdleQuestApp] porque é tudo infraestrutura, e o widget
/// raiz do jogo não deve conhecer Hive, `home_widget` nem canais de
/// notificação.
class _PlatformBridge extends StatefulWidget {
  const _PlatformBridge({
    required this.scheduler,
    required this.container,
    required this.child,
  });

  final SaveScheduler scheduler;
  final ProviderContainer container;
  final Widget child;

  @override
  State<_PlatformBridge> createState() => _PlatformBridgeState();
}

class _PlatformBridgeState extends State<_PlatformBridge>
    with WidgetsBindingObserver {
  /// Cadência de R-M11-02 com o app à frente. Em segundo plano ela só se
  /// mantém com o serviço em primeiro plano; sem ele vale o piso de 15 min do
  /// WorkManager e a projeção cobre a diferença (research.md R4).
  static const Duration _widgetRefresh = Duration(minutes: 1);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_widgetRefresh, (_) => _publish());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.scheduler.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(widget.scheduler.onAppPause());
        // R-M11-05: a persistente só existe com o app em segundo plano.
        unawaited(_publish(showStatus: true));
      case AppLifecycleState.resumed:
        unawaited(
          widget.container.read(notificationServiceProvider).dismissStatus(),
        );
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Projeta o estado atual e o publica no widget — e, em segundo plano, na
  /// notificação persistente.
  Future<void> _publish({bool showStatus = false}) async {
    try {
      final clock = widget.container.read(clockProvider);
      final snapshot = widget.container
          .read(combatControllerProvider.notifier)
          .snapshot(now: clock.now(), monotonicMillis: clock.monotonicMillis());
      final projection = StateProjector.project(
        state: snapshot,
        now: clock.now(),
      );

      await const HomeWidgetService().publish(projection);
      if (showStatus) {
        await widget.container
            .read(notificationServiceProvider)
            .showStatus(projection);
      }
    } on Object {
      // Widget e notificação são acessórios: falhar aqui não pode afetar o
      // jogo (SC-M11-04).
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
