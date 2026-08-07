import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../domain/entities/progress_position.dart';
import '../game/combat_arena.dart';
import '../providers/combat_providers.dart';
import '../providers/loot_providers.dart';
import '../providers/offline_providers.dart';
import '../widgets/progress_hud.dart';
import 'act_select_screen.dart';
import 'hero_detail_screen.dart';
import 'inventory_screen.dart';
import 'offline_summary_screen.dart';

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
      onFixedStep: (dt) {
        // CEN-M09-005: com resumo offline pendente, o combate não anda. O
        // acumulador da arena continua correndo, mas o passo é descartado —
        // o jogador não perde nem ganha nada enquanto lê o resumo.
        if (ref.read(offlineControllerProvider).blocksCombat) return;
        ref.read(combatControllerProvider.notifier).tick(dt);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(combatControllerProvider);
    final loot = ref.watch(lootControllerProvider);
    final offline = ref.watch(offlineControllerProvider);

    // O resumo cobre a tela inteira até ser dispensado.
    if (offline.report case final report?) {
      return OfflineSummaryScreen(report: report);
    }

    // Empurra o estado mais recente para a arena a cada rebuild.
    _arena.sync(
      session.combat,
      session.lastEvents,
      travelProgress: session.travelProgress,
    );

    // Um lote novo de drops vira popup uma única vez. Comparar o contador, e
    // não a lista, evita repetir o aviso a cada rebuild da tela.
    ref.listen(lootControllerProvider, (previous, next) {
      if (previous?.dropSequence == next.dropSequence) return;
      _arena.showLoot(next.recentDrops);
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ProgressHud(
              position: session.account.currentPosition,
              gold: session.account.gold,
              heroesInCombat: session.combat.activeHeroes.length,
              // Só oferece a volta a quem já concluiu algo — na primeira
              // sessão não há para onde voltar (R-M08-11).
              onTapProgress:
                  session.account.highestAct > 1 ||
                      session.account.highestDifficulty > 1
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ActSelectScreen(),
                      ),
                    )
                  : null,
            ),
            _InventoryBar(
              itemCount: loot.inventory.items.length,
              isFull: loot.inventoryFull,
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

/// Atalho para o inventário direto da tela de combate.
///
/// Existe por causa de SC-M05-01: comparar e equipar um item recém-dropado tem
/// de caber em 3 interações a partir daqui — abrir, tocar no item, equipar.
class _InventoryBar extends StatelessWidget {
  const _InventoryBar({required this.itemCount, required this.isFull});

  final int itemCount;
  final bool isFull;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF272238),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const InventoryScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Flexível com reticências: numa tela estreita, ou com fonte
              // ampliada por acessibilidade, é o rótulo que cede — não a barra
              // que estoura. Os atalhos à direita nunca podem sumir, porque
              // são o único caminho para Cubo, Runas e Loja.
              Flexible(
                child: Text(
                  'Inventário $itemCount/50',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isFull
                        ? const Color(0xFFD24B4B)
                        : Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              if (isFull)
                const Text(
                  'cheio',
                  style: TextStyle(fontSize: 11, color: Color(0xFFD24B4B)),
                ),
              const _BarLink(label: 'Cubo', route: Routes.cube),
              const _BarLink(label: 'Runas', route: Routes.runes),
              const _BarLink(label: 'Loja', route: Routes.store),
            ],
          ),
        ),
      ),
    );
  }
}

/// Atalho de texto para uma tela de profundidade (Cubo, Runas).
class _BarLink extends StatelessWidget {
  const _BarLink({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(route),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFFE8B44A)),
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
                child: Builder(
                  builder: (context) => InkWell(
                    // Tocar no herói abre seus 7 slots — o caminho de equipar
                    // sem passar pelo inventário (R-M05-02).
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HeroDetailScreen(heroId: hero.id),
                      ),
                    ),
                    child: _HeroCard(
                      name: hero.classId,
                      level: hero.level,
                      isDown: combatants
                          .where((c) => c.heroId == hero.id)
                          .any((c) => c.isIncapacitated),
                    ),
                  ),
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
