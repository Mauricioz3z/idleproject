/// Fluxo de aleatoriedade determinístico e reproduzível.
///
/// research.md R5: `dart:math`'s `Random(seed)` não garante estabilidade de
/// algoritmo entre versões do Dart, e um save de seis meses atrás precisa
/// continuar reproduzindo a mesma sequência. Por isso o gerador é próprio —
/// xorshift128+, rápido e com período longo o bastante para o uso do jogo.
///
/// O par `(seed, counter)` é persistido na conta. Restaurá-lo retoma o fluxo
/// exatamente onde parou, o que sustenta:
/// - equivalência entre combate ao vivo e simulação offline (research.md R3);
/// - ausência de duplicação ao reprocessar um intervalo (CEN-M10-E03);
/// - impossibilidade de save-scumming: fechar e reabrir não re-sorteia o drop.
class RngStream {
  RngStream({required this.seed, int counter = 0}) : _counter = 0 {
    _reset();
    // Avança até a posição salva. O custo é irrelevante: `counter` é reiniciado
    // a cada save e nunca cresce o bastante para isso pesar.
    for (var i = 0; i < counter; i++) {
      _next();
    }
    _counter = counter;
  }

  /// Semente do fluxo. Persistida em `PlayerAccount.rngSeed`.
  final int seed;

  int _counter;
  late int _s0;
  late int _s1;

  /// Subfluxos nomeados vivos, memoizados por rótulo. Ver [substream].
  final Map<String, RngStream> _substreams = {};

  /// Quantos valores já foram consumidos. Persistido em
  /// `PlayerAccount.rngCounter`.
  int get counter => _counter;

  void _reset() {
    // SplitMix64 para espalhar a semente antes de alimentar o xorshift.
    // Semear os dois estados com o mesmo valor produziria sequências pobres.
    var z = seed == 0 ? 0x9E3779B97F4A7C15 : seed;
    z = _splitMix(z);
    _s0 = z;
    z = _splitMix(z);
    _s1 = z;
    if (_s0 == 0 && _s1 == 0) _s0 = 0x9E3779B97F4A7C15;
  }

  static int _splitMix(int x) {
    var z = x + 0x9E3779B97F4A7C15;
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    return z ^ (z >>> 31);
  }

  int _next() {
    var s1 = _s0;
    final s0 = _s1;
    _s0 = s0;
    s1 ^= s1 << 23;
    _s1 = s1 ^ s0 ^ (s1 >>> 18) ^ (s0 >>> 5);
    _counter++;
    return _s1 + s0;
  }

  /// Valor em `[0,1)`.
  double nextDouble() {
    // 53 bits, a precisão exata da mantissa de um double — evita o viés de
    // pegar os bits baixos, que em xorshift são os de pior qualidade.
    final bits = _next() >>> 11;
    return bits / 9007199254740992.0; // 2^53
  }

  /// Inteiro em `[0, maxExclusive)`.
  int nextInt(int maxExclusive) {
    if (maxExclusive <= 0) return 0;
    return (nextDouble() * maxExclusive).floor().clamp(0, maxExclusive - 1);
  }

  /// Sorteia `true` com a probabilidade dada.
  bool chance(double probability) => nextDouble() < probability;

  /// Escolhe um elemento da lista.
  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// Deriva um subfluxo independente, identificado por [label].
  ///
  /// **Não avança o contador do pai** — é isso que permite ajustar a taxa de
  /// Essência sem deslocar todo o loot subsequente (R-M04-13). Se loot e
  /// Essência compartilhassem fluxo, mudar um número de balanceamento mudaria
  /// todos os itens que o jogador receberia dali em diante.
  RngStream fork(String label) =>
      RngStream(seed: _splitMix(seed ^ _hash(label) ^ _counter));

  /// Subfluxo nomeado **vivo**: a mesma instância é devolvida a cada chamada
  /// com o mesmo [label], de modo que consumos sucessivos avancem.
  ///
  /// [fork] deriva um fluxo novo a cada chamada, o que é o certo para um
  /// consumidor de vida longa que forka uma vez (o `CombatEngine`), e errado
  /// para um consumidor sem estado que sorteia repetidamente — cada sorteio
  /// receberia o mesmo fluxo do zero e devolveria sempre o mesmo resultado.
  /// `LootGenerator.rollEssence` é exatamente esse caso.
  ///
  /// A semente do filho depende só de `(seed, label)`, nunca do que o pai
  /// consumiu: é isso que sustenta R-M04-13 — mudar a taxa de Essência, ou
  /// sorteá-la mais vezes, não desloca nenhum item. O contador inicial vem do
  /// pai apenas para que reabrir o app não recomece a sequência de Essências
  /// do começo, o que reabriria a porta do save-scumming.
  RngStream substream(String label) => _substreams.putIfAbsent(
    label,
    () => RngStream(seed: _splitMix(seed ^ _hash(label)), counter: _counter),
  );

  /// FNV-1a de 32 bits sobre o rótulo.
  static int _hash(String label) {
    var h = 0x811C9DC5;
    for (var i = 0; i < label.length; i++) {
      h = (h ^ label.codeUnitAt(i)) * 0x01000193;
    }
    return h;
  }
}
