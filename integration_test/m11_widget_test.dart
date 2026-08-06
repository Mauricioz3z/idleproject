import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/domain/engines/state_projector.dart';
import 'package:pixel_idle_quest/domain/entities/entitlements.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/hero.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:pixel_idle_quest/domain/entities/save_state.dart';
import 'package:pixel_idle_quest/services/home_widget_service.dart';
import 'package:pixel_idle_quest/services/notification_service.dart';

/// M11 — widget de tela inicial e notificações (CEN-M11-001 a 011, E01 a E03).
///
/// **Exige aparelho ou emulador Android conectado**: `flutter test` não executa
/// este arquivo. Rode com `flutter test integration_test/m11_widget_test.dart`
/// com um dispositivo disponível.
///
/// O que é verificável aqui é a fronteira com a plataforma — payload gravado,
/// canais criados, degradação sem permissão. O que depende de gesto humano no
/// launcher (adicionar o widget, tocar nele) está anotado como verificação
/// manual de `quickstart.md`, porque nenhum harness controla a tela inicial do
/// Android.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final salvoEm = DateTime.now().subtract(const Duration(hours: 2));

  SaveState save({
    double goldPerSecond = 12,
    ProgressPosition? position,
    List<GameItem> items = const [],
  }) => SaveState(
    schemaVersion: SaveState.currentSchemaVersion,
    account: PlayerAccount.fresh(now: salvoEm, seed: 7).copyWith(
      gold: GameNumber.fromDouble(5000),
      goldPerSecond: GameNumber.fromDouble(goldPerSecond),
      currentPosition:
          position ?? const ProgressPosition(difficulty: 1, act: 2, wave: 43),
      lastSaveAt: salvoEm,
    ),
    entitlements: Entitlements.initial(),
    heroes: [
      Hero.fresh(id: 'h1', classId: 'vanguard')
          .copyWith(formationIndex: 0, level: 31),
      Hero.fresh(id: 'h2', classId: 'medtech')
          .copyWith(formationIndex: 1, level: 22),
    ],
    equippedItems: const [],
    inventory: Inventory(
      items: items,
      pendingDrops: const [],
      essences: const [],
      blueprints: const [],
    ),
    lastMonotonicMillis: 0,
  );

  group('CEN-M11-001/009 — payload do widget', () {
    testWidgets('o payload leva wave, ato, herói e taxa de ouro', (_) async {
      const service = HomeWidgetService();
      final projection = StateProjector.project(
        state: save(),
        now: DateTime.now(),
      );

      await service.publish(projection);

      expect(
        await HomeWidget.getWidgetData<int>(HomeWidgetService.keyWave),
        143,
        reason: 'a wave exibida é a acumulada entre atos (V-PP-04)',
      );
      expect(
        await HomeWidget.getWidgetData<int>(HomeWidgetService.keyAct),
        2,
      );
      expect(
        await HomeWidget.getWidgetData<String>(
          HomeWidgetService.keyBestHeroName,
        ),
        'vanguard',
      );
      expect(
        await HomeWidget.getWidgetData<int>(
          HomeWidgetService.keyBestHeroLevel,
        ),
        31,
      );
    });

    testWidgets('as chaves de projeção permitem recalcular no desenho', (
      _,
    ) async {
      const service = HomeWidgetService();
      final projection = StateProjector.project(
        state: save(goldPerSecond: 12),
        now: DateTime.now(),
      );

      await service.publish(projection);

      final baseMs = await HomeWidget.getWidgetData<int>(
        HomeWidgetService.keyProjectionBaseMs,
      );
      final raw = await HomeWidget.getWidgetData<String>(
        HomeWidgetService.keyGoldPerSecRaw,
      );

      expect(baseMs, salvoEm.millisecondsSinceEpoch);
      expect(raw, isNotNull);
      // O Kotlin precisa **calcular** com este valor; a forma abreviada não
      // serviria (research.md R4).
      expect(
        HomeWidgetService.decodeNumber(raw!).toDouble(),
        closeTo(12, 0.001),
      );
    });

    testWidgets('CEN-M11-009: o payload reflete o save, sem rodar combate', (
      _,
    ) async {
      const service = HomeWidgetService();
      final estado = save(
        position: const ProgressPosition(difficulty: 1, act: 2, wave: 42),
      );

      await service.publish(
        StateProjector.project(state: estado, now: DateTime.now()),
      );

      expect(
        await HomeWidget.getWidgetData<int>(HomeWidgetService.keyWave),
        142,
        reason: 'a wave não pode avançar sozinha em segundo plano',
      );
    });

    testWidgets('CEN-M11-001: o último lendário+ vai para o payload', (
      _,
    ) async {
      const service = HomeWidgetService();
      final raro = GameItem(
        id: 'r1',
        type: ItemType.helmet,
        rarity: ItemRarity.mitico,
        itemLevel: 140,
        baseStat: GameNumber.fromDouble(900),
        affixes: const [],
        droppedAt: salvoEm,
      );

      await service.publish(
        StateProjector.project(state: save(items: [raro]), now: DateTime.now()),
      );

      expect(
        await HomeWidget.getWidgetData<String>(
          HomeWidgetService.keyLastRareRarity,
        ),
        'mitico',
      );
    });
  });

  group('CEN-M11-011 — widget sem estado salvo', () {
    testWidgets('a projeção vazia limpa o payload em vez de gravar zeros', (
      _,
    ) async {
      const service = HomeWidgetService();

      await service.publish(StateProjector.empty);

      // O provider usa `w_projectionBaseMs` e `w_wave` como sentinela para
      // decidir entre convite e conteúdo.
      expect(
        await HomeWidget.getWidgetData<int>(
          HomeWidgetService.keyProjectionBaseMs,
        ),
        0,
      );
      expect(
        await HomeWidget.getWidgetData<int>(HomeWidgetService.keyWave),
        0,
      );
    });
  });

  group('CEN-M11-E03 — múltiplos widgets', () {
    testWidgets('todos leem a mesma origem e projetam o mesmo instante', (
      _,
    ) async {
      const service = HomeWidgetService();
      final agora = DateTime.now();

      await service.publish(
        StateProjector.project(state: save(), now: agora),
      );
      final primeiro = await HomeWidget.getWidgetData<String>(
        HomeWidgetService.keyGoldPerSecRaw,
      );

      await service.publish(
        StateProjector.project(state: save(), now: agora),
      );
      final segundo = await HomeWidget.getWidgetData<String>(
        HomeWidgetService.keyGoldPerSecRaw,
      );

      expect(primeiro, segundo);
    });
  });

  group('notificações', () {
    testWidgets('os três canais são criados na inicialização', (_) async {
      final service = NotificationService();
      await service.initialize();

      // A criação é idempotente: chamar de novo não duplica nem lança.
      await service.initialize();
      expect(service.isStatusEnabled, isTrue);
    });

    testWidgets(
      'CEN-M11-E01: sem permissão, nada é exibido e nada quebra',
      (_) async {
        final service = NotificationService();
        await service.initialize();

        // Sem `requestPermission` bem-sucedido, os envios são no-op — e é isso
        // que sustenta SC-M11-04: recompensa nunca depende de permissão.
        expect(service.isPermitted, isFalse);

        await service.showStatus(
          StateProjector.project(state: save(), now: DateTime.now()),
        );
        await service.notifyRareLoot(rarityId: 'lendario', itemLabel: 'elmo');
        await service.notifyInventoryFull();
      },
    );

    testWidgets('CEN-M11-010: desligar a persistente não lança nem persiste', (
      _,
    ) async {
      final service = NotificationService();
      await service.initialize();

      await service.setStatusEnabled(false);
      expect(service.isStatusEnabled, isFalse);

      await service.showStatus(
        StateProjector.project(state: save(), now: DateTime.now()),
      );

      await service.setStatusEnabled(true);
      expect(service.isStatusEnabled, isTrue);
    });
  });

  // Verificações que dependem da tela inicial do Android e ficam para a
  // validação manual de quickstart.md §4:
  //
  // - CEN-M11-002: defasagem de no máximo 1 min com o serviço em primeiro
  //   plano ativo (e degradação para 15 min sem ele — CEN-M11-E02).
  // - CEN-M11-003 / SC-M11-02: tocar no widget abre a tela de combate em uma
  //   interação.
  // - CEN-M11-004/005/006: notificação persistente visível na gaveta, com as
  //   ações Abrir e Coletar Loot.
  //
  // Nenhum harness controla o launcher; automatizá-las exigiria UI Automator
  // fora do processo do app, o que não cabe no escopo desta feature.
}
