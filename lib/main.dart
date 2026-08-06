import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/repositories/content_repository_impl.dart';
import 'data/repositories/hive_save_repository.dart';
import 'presentation/providers/combat_providers.dart';
import 'presentation/providers/offline_providers.dart';
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
    // A árvore de runas só é autorada em T123 (US6). Exigir os 200 nós agora
    // impediria o app de abrir por uma dependência de uma story futura.
    requireFullRuneTree: false,
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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _AppLifecycleSaves(
        scheduler: scheduler,
        child: const PixelIdleQuestApp(),
      ),
    ),
  );
}

/// Grava ao ir para segundo plano (R-M10-02).
///
/// Fica fora de [PixelIdleQuestApp] porque o agendador é infraestrutura, e o
/// widget raiz do jogo não deve conhecer Hive.
class _AppLifecycleSaves extends StatefulWidget {
  const _AppLifecycleSaves({required this.scheduler, required this.child});

  final SaveScheduler scheduler;
  final Widget child;

  @override
  State<_AppLifecycleSaves> createState() => _AppLifecycleSavesState();
}

class _AppLifecycleSavesState extends State<_AppLifecycleSaves>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.scheduler.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.scheduler.onAppPause());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
