import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/repositories/content_repository_impl.dart';
import 'presentation/providers/combat_providers.dart';

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

  runApp(
    ProviderScope(
      overrides: [
        combatDependenciesProvider.overrideWithValue(
          CombatDependencies(
            classes: content.heroClasses(),
            monsterTemplates: content.monsters(),
            seed: DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      ],
      child: const PixelIdleQuestApp(),
    ),
  );
}
