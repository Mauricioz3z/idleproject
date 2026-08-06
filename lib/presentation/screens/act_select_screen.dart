import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/scaling.dart';
import '../../core/numeric/number_format.dart';
import '../../domain/engines/wave_director.dart';
import '../../domain/entities/player_account.dart';
import '../../domain/entities/progress_position.dart';
import '../game/components/background_component.dart';
import '../providers/combat_providers.dart';

/// Seleção de ato e dificuldade já concluídos (R-M08-11, CEN-M08-011).
///
/// Existe por causa de CEN-M08-E01: quando uma wave fica pesada demais, voltar
/// para farmar é a saída prevista pela spec — e ela só funciona se o jogador
/// puder escolher para onde voltar. Nenhum recorde é tocado ao voltar.
class ActSelectScreen extends ConsumerWidget {
  const ActSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(combatControllerProvider).account;

    return Scaffold(
      appBar: AppBar(title: const Text('Atos e dificuldades')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _CurrentPosition(account: account),
          const SizedBox(height: 12),
          for (var difficulty = 1;
              difficulty <= account.highestDifficulty;
              difficulty++)
            _DifficultyBlock(account: account, difficulty: difficulty),
          const SizedBox(height: 16),
          const Text(
            'Voltar a conteúdo já concluído não reduz nenhum recorde. '
            'A wave escolhida sempre começa no início do ato.',
            style: TextStyle(fontSize: 11, color: Color(0xFFB4AAC6)),
          ),
        ],
      ),
    );
  }
}

class _CurrentPosition extends StatelessWidget {
  const _CurrentPosition({required this.account});

  final PlayerAccount account;

  @override
  Widget build(BuildContext context) {
    final p = account.currentPosition;
    return Container(
      color: const Color(0xFF272238),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agora: ${ActScenery.forAct(p.act).name}  ·  Wave ${p.wave}'
            '  ·  Dificuldade ${p.difficulty}',
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Recorde: wave ${account.highestWave}  ·  ato ${account.highestAct}'
            '  ·  dificuldade ${account.highestDifficulty}',
            style: const TextStyle(fontSize: 11, color: Color(0xFFB4AAC6)),
          ),
        ],
      ),
    );
  }
}

class _DifficultyBlock extends ConsumerWidget {
  const _DifficultyBlock({required this.account, required this.difficulty});

  final PlayerAccount account;
  final int difficulty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(combatControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dificuldade $difficulty'
            '${difficulty > 1 ? "  ·  monstros ×${_scaleLabel()}" : ""}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE8B44A),
            ),
          ),
          const SizedBox(height: 6),
          for (var act = ProgressPosition.minAct;
              act <= ProgressPosition.maxAct;
              act++)
            _ActTile(
              act: act,
              difficulty: difficulty,
              account: account,
              onSelect: () {
                controller.selectPosition(
                  ProgressPosition(
                    difficulty: difficulty,
                    act: act,
                    wave: 1,
                  ),
                );
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  /// Multiplicador acumulado desta dificuldade.
  ///
  /// Em [GameNumber], não em `double`: o fator é `1,5^(dificuldade−1)`, sem teto
  /// (R-M08-09). Acumulado em `double`, ele vira `Infinity` por volta da
  /// dificuldade 1750 — e muito antes disso já imprimia uma parede de dígitos.
  /// A mesma razão pela qual o jogo inteiro usa `GameNumber` vale para o rótulo
  /// que exibe o número (research.md R6, T147).
  String _scaleLabel() => NumberFormat.compact(
    MonsterScaling.difficultyFactor(
      ProgressPosition(difficulty: difficulty, act: 1, wave: 1),
    ),
  );
}

class _ActTile extends StatelessWidget {
  const _ActTile({
    required this.act,
    required this.difficulty,
    required this.account,
    required this.onSelect,
  });

  final int act;
  final int difficulty;
  final PlayerAccount account;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final target = ProgressPosition(difficulty: difficulty, act: act, wave: 1);
    final unlocked = WaveDirector.canSelect(account, target);
    final isCurrent =
        account.currentPosition.act == act &&
        account.currentPosition.difficulty == difficulty;
    final scenery = ActScenery.forAct(act);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF272238),
        border: Border.all(
          color: isCurrent ? const Color(0xFFE8B44A) : const Color(0xFF3A3548),
        ),
      ),
      child: ListTile(
        dense: true,
        enabled: unlocked && !isCurrent,
        leading: Container(width: 6, height: 32, color: scenery.accent),
        title: Text(
          'Ato $act — ${scenery.name}',
          style: TextStyle(
            fontSize: 13,
            color: unlocked ? Colors.white : const Color(0xFF5D5670),
          ),
        ),
        subtitle: Text(
          isCurrent
              ? 'você está aqui'
              : unlocked
              ? 'concluído — toque para voltar'
              : 'ainda não desbloqueado',
          style: const TextStyle(fontSize: 10, color: Color(0xFFB4AAC6)),
        ),
        onTap: unlocked && !isCurrent ? onSelect : null,
      ),
    );
  }
}
