import 'dart:io';

import 'package:test/test.dart';

/// Guarda de fronteira do núcleo de domínio.
///
/// plan.md (Structure Decision) exige que `lib/domain/` e `lib/core/` sejam
/// Dart puro. Não é preciosismo: `OfflineSimulator` tem que produzir exatamente
/// o mesmo resultado que `CombatEngine` produziria com o jogo aberto
/// (research.md R3). Se a regra de jogo mora dentro de um componente Flame, ela
/// fica acoplada ao ciclo de render e o simulador offline vira uma
/// reimplementação paralela — duas fontes de verdade que divergem com o tempo.
///
/// O analyzer não sabe expressar essa restrição, então ela vive aqui.
void main() {
  const forbidden = [
    'package:flutter/',
    'package:flame',
    'package:hive',
    'package:firebase',
    'package:google_mobile_ads',
    'package:in_app_purchase',
    'package:workmanager',
    'package:home_widget',
    'dart:ui',
    'dart:io',
  ];

  test('lib/domain/ e lib/core/ não importam Flutter, Flame nem plugins', () {
    final violations = <String>[];

    for (final dirName in ['lib/domain', 'lib/core']) {
      final dir = Directory(dirName);
      if (!dir.existsSync()) continue;

      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (!line.startsWith('import ') && !line.startsWith('export ')) {
            continue;
          }
          for (final banned in forbidden) {
            if (line.contains(banned)) {
              violations.add('${file.path}:${i + 1} -> $banned');
            }
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'O núcleo de domínio precisa ser Dart puro e testável headless.\n'
          'Violações:\n${violations.join("\n")}',
    );
  });
}
