import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/providers/offline_providers.dart';
import 'presentation/screens/combat_screen.dart';
import 'presentation/theme/app_theme.dart';

/// Raiz da aplicação.
class PixelIdleQuestApp extends ConsumerStatefulWidget {
  const PixelIdleQuestApp({super.key});

  @override
  ConsumerState<PixelIdleQuestApp> createState() => _PixelIdleQuestAppState();
}

class _PixelIdleQuestAppState extends ConsumerState<PixelIdleQuestApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // O boot carrega o save e resolve a ausência antes de o combate andar
    // (R-M09-06). O gate está em `OfflineState.blocksCombat`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(offlineControllerProvider.notifier).boot();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Nenhum combate roda com o app em segundo plano (R-M09-07): o
        // intervalo é resolvido aqui, na volta.
        ref.read(offlineControllerProvider.notifier).onResumeFromBackground();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixel Idle Quest',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const CombatScreen(),
    );
  }
}
