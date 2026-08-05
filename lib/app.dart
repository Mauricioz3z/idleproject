import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/screens/combat_screen.dart';
import 'presentation/theme/app_theme.dart';

/// Raiz da aplicação.
class PixelIdleQuestApp extends ConsumerWidget {
  const PixelIdleQuestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Pixel Idle Quest',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const CombatScreen(),
    );
  }
}
