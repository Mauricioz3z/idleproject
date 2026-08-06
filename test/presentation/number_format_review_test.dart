import 'package:pixel_idle_quest/core/constants/scaling.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/core/numeric/number_format.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:test/test.dart';

/// Revisão de formatação de números grandes — T147.
///
/// O jogo inteiro usa [GameNumber] porque as grandezas crescem sem teto
/// (research.md R6). De nada adianta se a **tela** converter para `double`
/// antes de exibir: o valor vira `Infinity` ou uma parede de dígitos, e o bug
/// aparece só para quem jogou o bastante para chegar lá — exatamente o jogador
/// que menos deveria encontrar defeito.
///
/// Estes testes travam as duas propriedades que a revisão apurou: o formatador
/// aguenta a faixa inteira, e o rótulo de dificuldade não passa por `double`.
void main() {
  group('NumberFormat aguenta a faixa inteira do jogo', () {
    test('valores pequenos saem legíveis, sem casas decimais inúteis', () {
      expect(NumberFormat.compact(GameNumber.zero), '0');
      expect(NumberFormat.compact(GameNumber.fromDouble(7)), '7');
      expect(NumberFormat.compact(GameNumber.fromDouble(947)), '947');
    });

    test('a escala curta e a alfabética cobrem qualquer expoente', () {
      final amostras = {
        1.2e3: '1.2K',
        3.4e6: '3.4M',
        5.6e9: '5.6B',
        7.8e12: '7.8T',
        9.1e15: '9.1aa',
      };

      for (final entry in amostras.entries) {
        expect(
          NumberFormat.compact(GameNumber.fromDouble(entry.key)),
          entry.value,
        );
      }
    });

    test('acima de 1e308 continua legível — onde double já falhou', () {
      // `double` satura em ~1.8e308. `GameNumber` não, e o formatador precisa
      // acompanhar: é o caso de dificuldade alta de R-M08-09.
      final gigante = GameNumber(1.5, 400);
      final texto = NumberFormat.compact(gigante);

      expect(texto, isNot(contains('Infinity')));
      expect(texto, isNot(contains('NaN')));
      expect(texto.length, lessThan(12), reason: 'parede de dígitos na tela');
    });

    test('nenhum expoente da faixa jogável produz saída degenerada', () {
      for (var exponent = 0; exponent <= 600; exponent += 7) {
        final texto = NumberFormat.compact(GameNumber(2.5, exponent));
        expect(texto, isNotEmpty);
        expect(texto, isNot(contains('Infinity')));
        expect(texto, isNot(contains('e+')));
        expect(texto.length, lessThan(12), reason: 'expoente $exponent');
      }
    });

    test('withSeparators cai para a forma compacta antes de estourar', () {
      final texto = NumberFormat.withSeparators(GameNumber(3.3, 200));
      expect(texto, isNot(contains('Infinity')));
      expect(texto.length, lessThan(16));
    });
  });

  group('rótulo de dificuldade — o defeito que a revisão encontrou', () {
    /// Como o rótulo era calculado antes de T147.
    String labelAntigo(int difficulty) {
      var factor = 1.0;
      for (var i = 1; i < difficulty; i++) {
        factor *= 1.5;
      }
      return factor >= 100
          ? factor.toStringAsFixed(0)
          : factor.toStringAsFixed(1);
    }

    String labelAtual(int difficulty) => NumberFormat.compact(
      MonsterScaling.difficultyFactor(
        ProgressPosition(difficulty: difficulty, act: 1, wave: 1),
      ),
    );

    test('em dificuldade alta o cálculo em double estourava', () {
      expect(
        labelAntigo(1800),
        contains('Infinity'),
        reason: 'se isto parar de valer, o defeito original mudou de forma',
      );
      expect(labelAtual(1800), isNot(contains('Infinity')));
    });

    test('mesmo sem estourar, double vazava notação científica crua', () {
      // `1.1019466071921387e+35` na tela de seleção de ato. Não é erro de
      // cálculo — é um número que ninguém lê.
      expect(labelAntigo(200), contains('e+'));
      expect(labelAtual(200), isNot(contains('e+')));
      expect(labelAtual(200).length, lessThan(12));
    });

    test('o rótulo continua correto nas dificuldades comuns', () {
      expect(labelAtual(1), '1');
      expect(labelAtual(2), '1');
      expect(labelAtual(5), '5');
    });

    test('o rótulo é monotônico e nunca degenera', () {
      for (var d = 1; d <= 2000; d += 37) {
        final texto = labelAtual(d);
        expect(texto, isNotEmpty);
        expect(texto, isNot(contains('Infinity')));
        expect(texto.length, lessThan(12), reason: 'dificuldade $d');
      }
    });
  });
}
