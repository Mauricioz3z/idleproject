import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/data/repositories/content_repository_impl.dart';
import 'package:pixel_idle_quest/domain/entities/essence.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/entities/offline_report.dart';
import 'package:pixel_idle_quest/presentation/providers/combat_providers.dart';
import 'package:pixel_idle_quest/presentation/providers/loot_providers.dart';
import 'package:pixel_idle_quest/presentation/providers/rune_providers.dart';
import 'package:pixel_idle_quest/presentation/screens/act_select_screen.dart';
import 'package:pixel_idle_quest/presentation/screens/cube_screen.dart';
import 'package:pixel_idle_quest/presentation/screens/hero_detail_screen.dart';
import 'package:pixel_idle_quest/presentation/screens/inventory_screen.dart';
import 'package:pixel_idle_quest/presentation/screens/offline_summary_screen.dart';
import 'package:pixel_idle_quest/presentation/screens/rune_tree_screen.dart';
import 'package:pixel_idle_quest/presentation/screens/settings_screen.dart';
import 'package:pixel_idle_quest/presentation/screens/store_screen.dart';
import 'package:pixel_idle_quest/presentation/theme/app_theme.dart';

/// Teste de fumaça de todas as telas navegáveis.
///
/// Companheiro de `combat_screen_boot_test.dart`, pela mesma razão: o jogo
/// passou meses com 408 testes verdes sem que nenhuma tela jamais tivesse sido
/// **montada**. Defeito de ciclo de vida ou de layout não aparece em teste de
/// domínio — aparece quando o jogador abre o app.
///
/// Cada tela é montada em duas larguras, porque estouro de `Row` só se
/// manifesta na estreita.
void main() {
  String read(String name) => File('assets/content/$name').readAsStringSync();

  late JsonContentRepository content;

  setUp(() {
    content = JsonContentRepository.fromJson(
      heroClassesJson: read('hero_classes.json'),
      monstersJson: read('monsters.json'),
      runeTreeJson: read('rune_tree.json'),
    );
  });

  GameItem item(String id, {ItemRarity rarity = ItemRarity.lendario}) =>
      GameItem(
        id: id,
        type: ItemType.weapon,
        rarity: rarity,
        itemLevel: 42,
        baseStat: GameNumber.fromDouble(180),
        affixes: [
          ItemAffix(
            affixType: AffixType.critChance,
            value: GameNumber.fromDouble(0.08),
          ),
        ],
        droppedAt: DateTime.utc(2026),
      );

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        combatDependenciesProvider.overrideWithValue(
          CombatDependencies(
            classes: content.heroClasses(),
            monsterTemplates: content.monsters(),
            seed: 777,
          ),
        ),
        runeTreeProvider.overrideWithValue(content.runeTree()),
      ],
    );
    // Inventário com conteúdo: tela vazia esconde justamente os widgets que
    // costumam estourar.
    c.read(lootControllerProvider.notifier).replaceInventory(
      Inventory(
        items: [for (var i = 0; i < 12; i++) item('i$i')],
        pendingDrops: const [],
        essences: [
          Essence(
            id: 'e1',
            guaranteedAffixType: AffixType.goldFind,
            droppedAt: DateTime.utc(2026),
          ),
        ],
        blueprints: const [],
      ),
    );
    return c;
  }

  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    required Size size,
  }) async {
    await tester.binding.setSurfaceSize(size);
    final c = container();
    addTearDown(c.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: AppTheme.dark(), home: screen),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  final telas = <String, Widget Function()>{
    'inventário': () => const InventoryScreen(),
    'cubo': () => const CubeScreen(),
    'runas': () => const RuneTreeScreen(),
    'loja': () => const StoreScreen(),
    'opções': () => const SettingsScreen(),
    'seleção de ato': () => const ActSelectScreen(),
    'detalhe do herói': () => const HeroDetailScreen(heroId: 'hero_0'),
    'resumo offline': () =>
        const OfflineSummaryScreen(report: OfflineReport.empty),
  };

  for (final entry in telas.entries) {
    testWidgets('${entry.key} monta em tela estreita', (tester) async {
      await mount(tester, entry.value(), size: const Size(360, 640));
      expect(tester.takeException(), isNull);
    });

    testWidgets('${entry.key} monta em tela larga', (tester) async {
      await mount(tester, entry.value(), size: const Size(800, 480));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a árvore de runas desenha os 210 nós sem estourar', (
    tester,
  ) async {
    await mount(tester, const RuneTreeScreen(), size: const Size(360, 640));

    expect(tester.takeException(), isNull);
    // O cabeçalho informa pontos e progresso desde o primeiro quadro
    // (CEN-M07-001).
    expect(find.textContaining('nós'), findsWidgets);
  });
}
