import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'presentation/providers/offline_providers.dart';
import 'presentation/screens/combat_screen.dart';
import 'presentation/screens/cube_screen.dart';
import 'presentation/screens/inventory_screen.dart';
import 'presentation/screens/rune_tree_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/theme/app_theme.dart';

/// Destinos de deep link (contracts/platform-android.md §4).
///
/// Todos abrem direto no destino, sem menu intermediário — é o que sustenta
/// SC-M11-02: do widget ao combate em uma interação.
abstract final class DeepLinks {
  static const String scheme = 'pixelidle';
  static const String combat = 'pixelidle://combat';
  static const String offlineSummary = 'pixelidle://offline-summary';
  static const String inventory = 'pixelidle://inventory';

  /// Nome de rota correspondente, ou `null` se o URI não for nosso.
  static String? routeFor(Uri? uri) {
    if (uri == null || uri.scheme != scheme) return null;
    return switch (uri.host) {
      'combat' => Routes.combat,
      'offline-summary' => Routes.combat, // o resumo é gate do combate
      'inventory' => Routes.inventory,
      _ => null,
    };
  }
}

abstract final class Routes {
  static const String combat = '/';
  static const String inventory = '/inventory';
  static const String settings = '/settings';
  static const String cube = '/cube';
  static const String runes = '/runes';
}

/// Raiz da aplicação.
class PixelIdleQuestApp extends ConsumerStatefulWidget {
  const PixelIdleQuestApp({super.key});

  @override
  ConsumerState<PixelIdleQuestApp> createState() => _PixelIdleQuestAppState();
}

class _PixelIdleQuestAppState extends ConsumerState<PixelIdleQuestApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // O boot carrega o save e resolve a ausência antes de o combate andar
    // (R-M09-06). O gate está em `OfflineState.blocksCombat`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(offlineControllerProvider.notifier).boot();
      _listenToWidgetLaunches();
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

  /// Toque no widget e ações da notificação chegam por aqui.
  void _listenToWidgetLaunches() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_navigateTo);
    HomeWidget.widgetClicked.listen(_navigateTo);
  }

  void _navigateTo(Uri? uri) {
    final route = DeepLinks.routeFor(uri);
    // A tela de combate já é a raiz e já mostra o resumo offline quando há um
    // pendente, então `combat` e `offline-summary` não precisam empilhar nada.
    if (route == null || route == Routes.combat) return;
    _navigator.currentState?.pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixel Idle Quest',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigator,
      initialRoute: Routes.combat,
      routes: {
        Routes.combat: (_) => const CombatScreen(),
        Routes.inventory: (_) => const InventoryScreen(),
        Routes.settings: (_) => const SettingsScreen(),
        Routes.cube: (_) => const CubeScreen(),
        Routes.runes: (_) => const RuneTreeScreen(),
      },
    );
  }
}
