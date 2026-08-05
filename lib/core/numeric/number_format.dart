import 'dart:math' as math;

import 'game_number.dart';

/// Formatação abreviada de [GameNumber] para exibição.
///
/// Um idle chega a valores que nenhum jogador lê por extenso. Depois de `T`
/// (1e12) as siglas de escala curta acabam, então usamos o esquema alfabético
/// padrão do gênero: `aa`, `ab`, ... `az`, `ba`, ... — 26² sufixos, suficientes
/// para muito além de qualquer dificuldade alcançável.
abstract final class NumberFormat {
  static const List<String> _shortScale = ['', 'K', 'M', 'B', 'T'];

  /// Formata para exibição: `1.2K`, `3.4M`, `5.6aa`.
  ///
  /// [decimals] controla as casas exibidas; valores abaixo de 1000 são
  /// mostrados como inteiros, porque "947.0" polui a HUD sem informar nada.
  static String compact(GameNumber value, {int decimals = 1}) {
    if (value.isZero) return '0';
    if (!value.isFinite) return '∞';

    final exp = value.exponent;
    if (exp < 3) {
      final raw = value.toDouble();
      return raw < 1000 ? raw.floor().toString() : raw.toStringAsFixed(0);
    }

    final tier = exp ~/ 3;
    final shifted = value.mantissa * math.pow(10, exp % 3);
    final suffix = _suffixFor(tier);
    return '${shifted.toStringAsFixed(decimals)}$suffix';
  }

  /// Formato longo com separador de milhar, para telas de detalhe onde o
  /// jogador quer o número exato (ex.: custo de respec).
  static String withSeparators(GameNumber value) {
    if (value.isZero) return '0';
    if (value.exponent > 15) return compact(value, decimals: 3);
    final digits = value.toDouble().floor().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String _suffixFor(int tier) {
    if (tier < _shortScale.length) return _shortScale[tier];
    // Além de T, esquema alfabético: aa, ab, ... az, ba, ...
    final index = tier - _shortScale.length;
    final first = index ~/ 26;
    final second = index % 26;
    final a = 'a'.codeUnitAt(0);
    return '${String.fromCharCode(a + first)}${String.fromCharCode(a + second)}';
  }
}
