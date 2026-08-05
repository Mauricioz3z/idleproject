import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:test/test.dart';

/// Testes de [GameNumber] — data-model.md, objetos de valor.
///
/// Cobre V-GN-01 (normalização), V-GN-02 (saturação em zero) e a razão de ser
/// do tipo, documentada em research.md R6: o escalonamento de dificuldade de
/// x1,5 sem teto estoura int64, e em Dart nativo o transbordo é silencioso.
void main() {
  group('V-GN-01 normalização', () {
    test('mantissa é normalizada para [1,10)', () {
      final n = GameNumber(1234.5, 0);
      expect(n.mantissa, closeTo(1.2345, 1e-9));
      expect(n.exponent, 3);
    });

    test('mantissa menor que 1 é normalizada para cima', () {
      final n = GameNumber(0.00042, 0);
      expect(n.mantissa, closeTo(4.2, 1e-9));
      expect(n.exponent, -4);
    });

    test('zero tem mantissa e expoente zerados', () {
      expect(GameNumber.zero.mantissa, 0);
      expect(GameNumber.zero.exponent, 0);
      expect(GameNumber(0, 42).exponent, 0);
    });

    test('valor já normalizado permanece inalterado', () {
      final n = GameNumber(3.14, 7);
      expect(n.mantissa, closeTo(3.14, 1e-9));
      expect(n.exponent, 7);
    });
  });

  group('V-GN-02 saturação em zero', () {
    test('subtração que resultaria em negativo satura em zero', () {
      final a = GameNumber.fromInt(50);
      final b = GameNumber.fromInt(80);
      expect(a - b, GameNumber.zero);
    });

    test('subtração exata resulta em zero', () {
      final a = GameNumber.fromInt(100);
      expect(a - a, GameNumber.zero);
    });

    test('subtração normal preserva o valor', () {
      final r = GameNumber.fromInt(100) - GameNumber.fromInt(30);
      expect(r.toDouble(), closeTo(70, 1e-6));
    });
  });

  group('aritmética acima de 1e18 — o motivo do tipo existir', () {
    test('int64 estouraria onde GameNumber não estoura', () {
      // 1,5^108 passa de 9,22e18, o teto de int64 (research.md R6).
      var n = GameNumber.fromInt(1);
      final factor = GameNumber(1.5, 0);
      for (var i = 0; i < 120; i++) {
        n = n * factor;
      }
      expect(n.exponent, greaterThan(18));
      expect(n.mantissa, inInclusiveRange(1.0, 10.0));
    });

    test('HP base 1e6 escalado por 1,5^80 ultrapassa o teto de int64', () {
      var hp = GameNumber(1, 6);
      final factor = GameNumber(1.5, 0);
      for (var i = 0; i < 80; i++) {
        hp = hp * factor;
      }
      // int64 vai até ~9,22e18; aqui já estamos na casa de 1e20.
      expect(hp.exponent, greaterThan(18));
      expect(hp.isFinite, isTrue);
    });

    test('soma de grandezas com expoentes muito distantes preserva a maior', () {
      final grande = GameNumber(5, 40);
      final pequeno = GameNumber(3, 2);
      final soma = grande + pequeno;
      expect(soma.exponent, 40);
      expect(soma.mantissa, closeTo(5, 1e-9));
    });

    test('soma de grandezas próximas é exata o bastante', () {
      final soma = GameNumber(1.5, 20) + GameNumber(2.5, 20);
      expect(soma.mantissa, closeTo(4.0, 1e-9));
      expect(soma.exponent, 20);
    });
  });

  group('comparação e ordenação', () {
    test('expoente domina a comparação', () {
      expect(GameNumber(1, 10) > GameNumber(9.99, 9), isTrue);
    });

    test('mantissa decide quando o expoente empata', () {
      expect(GameNumber(2, 5) > GameNumber(1.9, 5), isTrue);
    });

    test('zero é menor que qualquer positivo', () {
      expect(GameNumber.zero < GameNumber(1, -30), isTrue);
    });

    test('igualdade tolera erro de ponto flutuante', () {
      expect(GameNumber.fromInt(100), GameNumber(1, 2));
    });
  });

  group('conversões', () {
    test('fromInt e toDouble são simétricos em faixa segura', () {
      expect(GameNumber.fromInt(123456).toDouble(), closeTo(123456, 1e-6));
    });

    test('multiplicação por zero resulta em zero', () {
      expect(GameNumber(7, 30) * GameNumber.zero, GameNumber.zero);
    });

    test('divisão por zero resulta em zero, não em NaN', () {
      expect(GameNumber(7, 3) / GameNumber.zero, GameNumber.zero);
    });
  });
}
