import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/numeric/number_format.dart';
import '../../domain/entities/offline_report.dart';
import '../game/components/loot_popup_component.dart';
import '../providers/offline_providers.dart';

/// Resumo do que aconteceu durante a ausência (R-M09-06, CEN-M09-005).
///
/// É modal por exigência da spec: o combate ao vivo só retoma depois que o
/// jogador dispensa o resumo. Um resumo que some sozinho enquanto o jogo já
/// voltou a rodar não cumpre o papel de mostrar que a ausência valeu a pena.
class OfflineSummaryScreen extends ConsumerWidget {
  const OfflineSummaryScreen({required this.report, super.key});

  final OfflineReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Enquanto você esteve fora',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _elapsedLabel(report),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB4AAC6),
                    ),
                  ),
                  if (report.wasCapped) ...[
                    const SizedBox(height: 8),
                    const _CapNotice(),
                  ],
                  const SizedBox(height: 20),
                  _Line(
                    label: 'Ouro',
                    value: NumberFormat.compact(report.goldGained),
                    accent: const Color(0xFFE8B44A),
                  ),
                  if (!report.goldFromAutoSell.isZero)
                    _Line(
                      label: 'Ouro de venda automática',
                      value: NumberFormat.compact(report.goldFromAutoSell),
                    ),
                  _Line(
                    label: 'XP',
                    value: NumberFormat.compact(report.xpGained),
                  ),
                  _Line(
                    label: 'Waves avançadas',
                    value: '${report.wavesAdvanced}',
                  ),
                  _Line(
                    label: 'Itens obtidos',
                    value: '${report.itemsObtained.length}',
                  ),
                  if (report.levelUps.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _SectionTitle('Subidas de nível'),
                    for (final up in report.levelUps)
                      _Line(
                        label: up.heroId,
                        value: 'Nv ${up.from} → ${up.to}',
                      ),
                  ],
                  if (report.rareHighlights.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _SectionTitle('Achados raros'),
                    for (final item in report.rareHighlights.take(10))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              color: RarityPalette.of(item.rarity),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${item.rarity.id} ${item.type.id} '
                              'iLv${item.itemLevel}',
                              style: TextStyle(
                                fontSize: 12,
                                color: RarityPalette.of(item.rarity),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (report.inventoryBecameFull) ...[
                    const SizedBox(height: 16),
                    const _FullNotice(),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => ref
                      .read(offlineControllerProvider.notifier)
                      .dismissReport(),
                  child: const Text('Continuar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _elapsedLabel(OfflineReport report) {
    final d = report.elapsed;
    if (d.inHours > 0) {
      final minutes = d.inMinutes.remainder(60);
      return '${d.inHours} h${minutes > 0 ? " $minutes min" : ""} de ausência';
    }
    if (d.inMinutes > 0) return '${d.inMinutes} min de ausência';
    return '${d.inSeconds} s de ausência';
  }
}

/// O teto precisa ser explicado, senão parece que o jogo engoliu progresso.
class _CapNotice extends StatelessWidget {
  const _CapNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2E2740),
      padding: const EdgeInsets.all(10),
      child: const Text(
        'A simulação considera no máximo 8 horas. O tempo além disso não '
        'rende ganhos.',
        style: TextStyle(fontSize: 11, color: Color(0xFFB4AAC6)),
      ),
    );
  }
}

class _FullNotice extends StatelessWidget {
  const _FullNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF4A2A2A),
      padding: const EdgeInsets.all(10),
      child: const Text(
        'Seu inventário encheu durante a ausência. Os itens que não couberam '
        'ficaram retidos e entram assim que houver espaço.',
        style: TextStyle(fontSize: 11, color: Color(0xFFE8B44A)),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFFB4AAC6)),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: accent ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
