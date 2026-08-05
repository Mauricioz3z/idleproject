import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:hive/hive.dart';
import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/data/repositories/hive_save_repository.dart';
import 'package:pixel_idle_quest/domain/entities/entitlements.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/hero.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:pixel_idle_quest/domain/entities/save_state.dart';
import 'package:pixel_idle_quest/domain/ports/save_repository.dart';
import 'package:pixel_idle_quest/services/save_scheduler.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';

/// M10 — Persistência e Salvamento.
/// Cenários CEN-M10-001 a 010 e E01 a E03.
void main() {
  late Directory tempDir;
  late Box<dynamic> metaBox;
  late Box<dynamic> saveBox;
  late HiveSaveRepository repo;

  final now = DateTime.fromMillisecondsSinceEpoch(1785600000000);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pixelidle_test_');
    Hive.init(tempDir.path);
    metaBox = await Hive.openBox<dynamic>('meta');
    saveBox = await Hive.openBox<dynamic>('save');
    repo = HiveSaveRepository(metaBox: metaBox, saveBox: saveBox);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  GameItem item(String id) => GameItem(
    id: id,
    type: ItemType.weapon,
    rarity: ItemRarity.epico,
    itemLevel: 143,
    baseStat: GameNumber(3.4, 4),
    affixes: const [],
    droppedAt: now,
  );

  SaveState richState() {
    final hero = Hero.fresh(id: 'h-1', classId: 'vanguard').copyWith(
      level: 31,
      formationIndex: 0,
    );
    final (equipped, _) = hero.equipItem(ItemType.weapon, 'i-arma');
    final (fullyEquipped, _) = equipped.equipItem(ItemType.armor, 'i-armadura');

    return SaveState(
      schemaVersion: 1,
      account: PlayerAccount.fresh(now: now, seed: 42).copyWith(
        accountLevel: 24,
        gold: GameNumber(8.31, 14),
        unlockedRuneNodeIds: {for (var i = 0; i < 12; i++) 'no_$i'},
        // Wave é relativa ao ato (1..100); o jogador vê 142 pelo globalWave.
        currentPosition: const ProgressPosition(
          difficulty: 1,
          act: 2,
          wave: 42,
        ),
        highestWave: 142,
        highestAct: 2,
      ),
      entitlements: Entitlements.initial(),
      heroes: [fullyEquipped],
      equippedItems: [item('i-arma'), item('i-armadura')],
      inventory: Inventory(
        items: [for (var i = 0; i < 40; i++) item('inv-$i')],
        pendingDrops: const [],
        essences: const [],
        blueprints: const [],
      ),
      lastMonotonicMillis: 84321000,
    );
  }

  group('CEN-M10-001/002 — cadência de gravação', () {
    test('CEN-M10-001: auto-save dispara a cada 30 s', () {
      // Tempo simulado, não relógio de parede: cravar o intervalo com
      // Future.delayed torna o teste dependente da carga da máquina, e ele
      // falha de forma intermitente — pior do que não existir.
      final gravacoes = _RecordingRepository();
      final clock = FakeClock(start: now);

      FakeAsync().run((async) {
        SaveScheduler(
          repository: gravacoes,
          clock: clock,
          snapshot: richState,
        ).start();

        async.elapse(const Duration(seconds: 29));
        expect(gravacoes.count, 0, reason: 'não deve salvar antes de 30 s');

        async.elapse(const Duration(seconds: 1));
        expect(gravacoes.count, 1);

        async.elapse(const Duration(seconds: 60));
        expect(gravacoes.count, 3, reason: 'uma gravação a cada 30 s');
      });
    });

    test('parar o agendador interrompe as gravações', () {
      final gravacoes = _RecordingRepository();
      final clock = FakeClock(start: now);

      FakeAsync().run((async) {
        final scheduler = SaveScheduler(
          repository: gravacoes,
          clock: clock,
          snapshot: richState,
        )..start();

        async.elapse(const Duration(seconds: 30));
        expect(gravacoes.count, 1);

        scheduler.stop();
        async.elapse(const Duration(minutes: 5));
        expect(gravacoes.count, 1, reason: 'nada após stop()');
      });
    });

    test('CEN-M10-002: onAppPause grava imediatamente', () async {
      final clock = FakeClock(start: now);
      final scheduler = SaveScheduler(
        repository: repo,
        clock: clock,
        snapshot: richState,
      );

      // Sem start(): só a pausa provoca a gravação.
      await scheduler.onAppPause();

      final loaded = await repo.load();
      expect(loaded, isNotNull);
      expect(loaded!.account.lastSaveAt, clock.now());
    });

    test('o momento do save é registrado pelo relógio injetado', () async {
      final clock = FakeClock(start: now);
      final scheduler = SaveScheduler(
        repository: repo,
        clock: clock,
        snapshot: richState,
      );
      clock.advance(const Duration(hours: 3));
      await scheduler.saveNow();

      final loaded = await repo.load();
      expect(loaded!.account.lastSaveAt, now.add(const Duration(hours: 3)));
      expect(loaded.lastMonotonicMillis, clock.monotonicMillis());
    });
  });

  group('CEN-M10-003/004 — escopo e restauração', () {
    test('CEN-M10-003: conta, heróis, inventário e momento são persistidos',
        () async {
      await repo.save(richState());
      final loaded = await repo.load();

      expect(loaded!.account.accountLevel, 24);
      expect(loaded.account.gold, GameNumber(8.31, 14));
      expect(loaded.heroes, hasLength(1));
      expect(loaded.inventory.items, hasLength(40));
      expect(loaded.account.lastSaveAt, isNotNull);
    });

    test('CEN-M10-004: restauração devolve heróis, itens e posição', () async {
      await repo.save(richState());
      final loaded = await repo.load();

      expect(loaded!.heroes.single.level, 31);
      expect(loaded.inventory.items.length, 40);
      expect(loaded.account.currentPosition.act, 2);
      expect(loaded.account.currentPosition.wave, 42);
      expect(loaded.account.currentPosition.globalWave, 142);
    });

    test('primeira execução devolve null, sem erro', () async {
      expect(await repo.load(), isNull);
    });
  });

  group('CEN-M10-007 — save corrompido', () {
    test('gravação interrompida não substitui o commit anterior', () async {
      await repo.save(richState());

      // Simula gravação interrompida: pendente escrito, promoção nunca ocorreu.
      await saveBox.put('pending', {'schemaVersion': 1, 'lixo': true});
      await saveBox.flush();

      final loaded = await repo.load();
      expect(loaded, isNotNull);
      expect(loaded!.account.accountLevel, 24, reason: 'commit anterior intacto');
      expect(loaded.heroes, hasLength(1));
    });
  });

  group('CEN-M10-008/009 — o que precisa sobreviver', () {
    test('CEN-M10-008: itens equipados continuam equipados no mesmo herói',
        () async {
      await repo.save(richState());
      final loaded = await repo.load();

      final hero = loaded!.heroes.single;
      expect(hero.equipment[ItemType.weapon], 'i-arma');
      expect(hero.equipment[ItemType.armor], 'i-armadura');
      expect(loaded.equippedItems.map((i) => i.id), containsAll(
        ['i-arma', 'i-armadura'],
      ));
    });

    test('CEN-M10-009: nós de runa desbloqueados persistem', () async {
      await repo.save(richState());
      final loaded = await repo.load();
      expect(loaded!.account.unlockedRuneNodeIds, hasLength(12));
    });

    test('CEN-M10-010: nada exige conta em nuvem', () async {
      // O repositório local não recebe credencial nem faz rede: se este teste
      // passa offline, backup em nuvem é de fato opcional.
      await repo.save(richState());
      expect(await repo.load(), isNotNull);
    });
  });

  group('CEN-M10-E01/E03 — bordas', () {
    test('CEN-M10-E01: wave parcial não é persistida; volta ao início da wave',
        () async {
      // A posição salva sempre aponta para o começo de uma wave (V-PP-03).
      // Não existe campo de progresso intra-wave no schema — é o que garante
      // o comportamento, e este teste trava essa ausência.
      await repo.save(richState());
      final loaded = await repo.load();

      expect(loaded!.account.currentPosition.wave, 42);
      expect(loaded.account.currentPosition.globalWave, 142);
      // HP corrente e temporizadores são derivados, nunca gravados.
      expect(loaded.heroes.single.currentHp, GameNumber.zero);
      expect(loaded.heroes.single.reviveAtMs, isNull);
    });

    test('CEN-M10-E03: gravações concorrentes deixam um estado consistente',
        () async {
      final a = richState();
      final b = richState().copyWith(
        account: richState().account.copyWith(accountLevel: 99),
      );

      await Future.wait([repo.save(a), repo.save(b)]);

      final loaded = await repo.load();
      expect(loaded, isNotNull);
      // Um dos dois venceu por inteiro; nenhum meio-termo sobrevive.
      expect([24, 99], contains(loaded!.account.accountLevel));
      expect(loaded.heroes, hasLength(1), reason: 'sem duplicação');
      expect(loaded.inventory.items, hasLength(40));
    });
  });

  group('CEN-M10-E02 — falha de armazenamento', () {
    test('falha ao gravar é classificada e não derruba o jogo', () async {
      final failing = _FailingRepository();
      final clock = FakeClock(start: now);
      Object? reported;

      final scheduler = SaveScheduler(
        repository: failing,
        clock: clock,
        snapshot: richState,
        onError: (e) => reported = e,
      );

      // saveNow engole o erro e reporta — o jogo continua.
      await scheduler.saveNow();

      expect(reported, isNotNull);
      expect(reported.toString(), contains('No space'));
    });
  });
}

/// Repositório em memória que conta gravações, para testar a cadência sem I/O.
class _RecordingRepository implements SaveRepository {
  int count = 0;
  SaveState? last;

  @override
  Future<void> clear() async {
    last = null;
    count = 0;
  }

  @override
  Future<SaveState?> load() async => last;

  @override
  Future<void> save(SaveState state) async {
    count++;
    last = state;
  }
}

/// Repositório que sempre falha por disco cheio.
class _FailingRepository implements SaveRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<SaveState?> load() async => null;

  @override
  Future<void> save(SaveState state) async =>
      throw const FileSystemException('No space left on device');
}
