import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';

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

  runApp(const ProviderScope(child: PixelIdleQuestApp()));
}
