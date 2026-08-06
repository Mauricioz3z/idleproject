import '../../core/numeric/game_number.dart';
import '../entities/game_item.dart';
import '../entities/hero.dart';
import '../entities/progress_position.dart';
import '../entities/save_state.dart';
import 'offline_simulator.dart';

/// Estado do jogo projetado para um instante, sem rodar combate.
class ProjectedState {
  const ProjectedState({
    required this.hasSave,
    required this.position,
    required this.goldPerSecond,
    required this.projectedGold,
    required this.projectedGain,
    required this.elapsed,
    required this.heroesInFormation,
    required this.bestHeroClassId,
    required this.bestHeroLevel,
    required this.lastRare,
    required this.baseTimestampMs,
  });

  /// CEN-M11-011: widget adicionado antes da primeira abertura. Tudo vazio, e
  /// nenhum zero apresentado como se fosse estado real.
  static const ProjectedState empty = ProjectedState(
    hasSave: false,
    position: null,
    goldPerSecond: GameNumber.zero,
    projectedGold: GameNumber.zero,
    projectedGain: GameNumber.zero,
    elapsed: Duration.zero,
    heroesInFormation: 0,
    bestHeroClassId: null,
    bestHeroLevel: 0,
    lastRare: null,
    baseTimestampMs: 0,
  );

  final bool hasSave;

  /// Posição **salva**, não projetada. Avançar a wave exigiria rodar combate,
  /// que é justamente o que R-M09-07 proíbe fora do app.
  final ProgressPosition? position;

  final GameNumber goldPerSecond;

  /// Ouro salvo mais o projetado para [elapsed].
  final GameNumber projectedGold;

  /// Só a parte projetada.
  final GameNumber projectedGain;

  /// Já saturado em zero e limitado ao teto de 8 h.
  final Duration elapsed;

  final int heroesInFormation;

  /// Maior nível da formação ativa (suposição declarada em M11).
  final String? bestHeroClassId;
  final int bestHeroLevel;

  /// Último item lendário ou superior obtido (R-M11-03).
  final GameItem? lastRare;

  /// Epoch do estado real que serve de base à projeção. É o que o provider
  /// Kotlin usa para reprojetar no instante do desenho.
  final int baseTimestampMs;

  /// R-M11-06: a notificação fala em ouro por minuto.
  GameNumber get goldPerMinute => goldPerSecond.scaled(60);
}

/// Projeta o estado a partir de `(save, tempo decorrido)` — research.md R4.
///
/// Existe porque o Android impõe piso de ~15 min entre atualizações fora de um
/// serviço em primeiro plano. A saída não é atualizar mais vezes, é atualizar
/// com informação melhor: como o estado do jogo fechado é função determinística
/// do save e do tempo, o widget calcula onde o jogador estaria **no instante em
/// que desenha**.
///
/// As constantes vêm de [OfflineSimulator] em vez de serem redeclaradas: se o
/// widget usasse o próprio teto ou a própria penalidade, ele passaria a
/// prometer um número que o resumo da reabertura não confirmaria — e a
/// discrepância apareceria justamente no momento em que o jogador está mais
/// atento ao ganho.
abstract final class StateProjector {
  static const double penalty = OfflineSimulator.offlinePenalty;
  static const int maxSeconds = OfflineSimulator.maxOfflineSeconds;

  /// Projeção de quem ainda não tem save (CEN-M11-011).
  static const ProjectedState empty = ProjectedState.empty;

  static ProjectedState project({
    required SaveState state,
    required DateTime now,
  }) {
    final account = state.account;
    final lastSaveAt = account.lastSaveAt;
    final hasBase = lastSaveAt.millisecondsSinceEpoch > 0;

    final rawSeconds = hasBase ? now.difference(lastSaveAt).inSeconds : 0;
    final seconds = rawSeconds <= 0
        ? 0
        : (rawSeconds > maxSeconds ? maxSeconds : rawSeconds);

    final gain = account.goldPerSecond
        .scaled(seconds.toDouble())
        .scaled(penalty);

    final formation = state.heroes.where((h) => h.isInFormation).toList();
    final best = _bestHero(formation);

    return ProjectedState(
      hasSave: true,
      position: account.currentPosition,
      goldPerSecond: account.goldPerSecond,
      projectedGold: account.gold + gain,
      projectedGain: gain,
      elapsed: Duration(seconds: seconds),
      heroesInFormation: formation.length,
      bestHeroClassId: best?.classId,
      bestHeroLevel: best?.level ?? 0,
      lastRare: _lastRare(state),
      baseTimestampMs: lastSaveAt.millisecondsSinceEpoch,
    );
  }

  static Hero? _bestHero(List<Hero> formation) {
    Hero? best;
    for (final hero in formation) {
      if (best == null || hero.level > best.level) best = hero;
    }
    return best;
  }

  /// Último lendário+ obtido, pelo momento do drop.
  ///
  /// Varre inventário, retidos e equipados: um item raro que o jogador já
  /// vestiu continua sendo o último raro que ele obteve, e sumir do widget ao
  /// equipar seria confuso.
  static GameItem? _lastRare(SaveState state) {
    GameItem? found;
    for (final item in [
      ...state.inventory.items,
      ...state.inventory.pendingDrops,
      ...state.equippedItems,
    ]) {
      if (!item.rarity.isRareHighlight) continue;
      // Empate de instante resolve pela ordem da lista: `intake` acrescenta ao
      // fim, então o mais recente é o último. Com `isAfter` estrito, dois itens
      // do mesmo tick manteriam o primeiro, que é o mais antigo dos dois.
      if (found == null || !item.droppedAt.isBefore(found.droppedAt)) {
        found = item;
      }
    }
    return found;
  }
}
