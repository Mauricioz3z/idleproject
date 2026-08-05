import 'package:flutter/material.dart';

/// Tema do jogo.
///
/// `specification.md` §7.1 pede UI minimalista, sem bordas arredondadas e fonte
/// pixelada. A fonte entra na Fase 10 junto com a arte final; aqui ficam as
/// decisões estruturais que não dependem de asset.
abstract final class AppTheme {
  static const Color _background = Color(0xFF12101A);
  static const Color _surface = Color(0xFF1E1B2E);
  static const Color _accent = Color(0xFFE8B44A);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: _background,
      colorScheme: base.colorScheme.copyWith(
        surface: _surface,
        primary: _accent,
      ),
      // Cantos retos em toda a UI, conforme §7.1.
      cardTheme: const CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
    );
  }
}
