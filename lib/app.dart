import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/theme/app_theme.dart';

/// Raiz da aplicação.
///
/// Ainda sem navegação e sem telas de jogo: essas chegam com US1 (tela de
/// combate), US2 (inventário) e seguintes. Aqui fica apenas o esqueleto que a
/// Fase 2 precisa entregar.
class PixelIdleQuestApp extends ConsumerWidget {
  const PixelIdleQuestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Pixel Idle Quest',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const _BootScreen(),
    );
  }
}

/// Tela provisória da fundação. Substituída pela tela de combate em US1 (T055).
class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Pixel Idle Quest\nfundação pronta',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
