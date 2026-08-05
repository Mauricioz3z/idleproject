import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/progress_position.dart';
import '../game/combat_arena.dart';
import '../providers/combat_providers.dart';
import '../widgets/progress_hud.dart';

/// Tela de combate — a tela principal do jogo.
///
/// Não há um único controle de ataque: o combate é automático (R-M01-07). Tudo
/// aqui é leitura, e é isso que faz o jogador ver progresso em até 10 segundos
/// sem tocar em nada (SC-M01-01).
class CombatScreen extends ConsumerStatefulWidget {
  const CombatScreen({super.key});

  @override
  ConsumerState<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends ConsumerState<CombatScreen> {
  late final CombatArena _arena;

  @override
  void initState() {
    super.initState();
    _arena = CombatArena(
      onFixedStep: (dt) => ref.read(combatControllerProvider.notifier).tick(dt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(combatControllerProvider);

    // Empurra o estado mais recente para a arena a cada rebuild.
    _arena.sync(session.combat, session.lastEvents);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ProgressHud(
              position: session.account.currentPosition,
              gold: session.account.gold,
              heroesInCombat: session.combat.activeHeroes.length,
            ),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFF191527),
                child: GameWidget(game: _arena),
              ),
            ),
            _FormationBar(session: session),
          ],
        ),
      ),
    );
  }
}

/// Barra inferior com os heróis da formação: nível, XP e estado.
class _FormationBar extends StatelessWidget {
  const _FormationBar({required this.session});

  final CombatSession session;

  @override
  Widget build(BuildContext context) {
    final combatants = session.combat.heroes;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFF1E1B2E),
      child: Row(
        children: [
          for (final hero in session.heroes)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _HeroCard(
                  name: hero.classId,
                  level: hero.level,
                  isDown: combatants
                      .where((c) => c.heroId == hero.id)
                      .any((c) => c.isIncapacitated),
                ),
              ),
            ),
          if (session.heroes.length < session.account.formationSlots)
            const Expanded(child: _EmptySlot()),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.name,
    required this.level,
    required this.isDown,
  });

  final String name;
  final int level;
  final bool isDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const Color(0xFF272238),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: isDown ? const Color(0xFF7A7189) : Colors.white,
            ),
          ),
          Text(
            isDown ? 'revivendo…' : 'Nv $level',
            style: TextStyle(
              fontSize: 10,
              color: isDown
                  ? const Color(0xFFD24B4B)
                  : const Color(0xFFB4AAC6),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF3A3548)),
      ),
      child: const Text(
        'slot livre',
        style: TextStyle(fontSize: 10, color: Color(0xFF5D5670)),
      ),
    );
  }
}

/// Formata a posição para exibição, usando a numeração acumulada que o jogador
/// enxerga — "Wave 142 (Ato 2)" — e não a wave relativa ao ato (V-PP-04).
String formatPosition(ProgressPosition p) =>
    'Wave ${p.globalWave} (Ato ${p.act})';
