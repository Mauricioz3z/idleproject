import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_idle_quest/data/repositories/content_repository_impl.dart';
import 'package:pixel_idle_quest/presentation/providers/combat_providers.dart';
import 'package:pixel_idle_quest/presentation/providers/rune_providers.dart';
import 'package:pixel_idle_quest/presentation/screens/combat_screen.dart';
import 'package:pixel_idle_quest/presentation/theme/app_theme.dart';

/// A tela de combate sobe e sobrevive aos primeiros quadros.
///
/// Este arquivo existe por causa de um defeito que passou por 408 testes, por
/// `flutter analyze` e por dois builds de APK, e só apareceu ao abrir o jogo no
/// aparelho: `CombatArena.sync` é chamado do `build` da tela, que roda **antes**
/// de o `GameWidget` ter layout — e ler `size` do jogo ali lança
/// `'hasLayout': "size" is not ready yet`, com tela vermelha na abertura.
///
/// Nenhum teste de domínio pega isso, porque não é regra de jogo: é ciclo de
/// vida de widget. O que faltava era exatamente isto — montar a tela de verdade
/// e deixar alguns quadros passarem.
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

  Widget app() => ProviderScope(
    overrides: [
      combatDependenciesProvider.overrideWithValue(
        CombatDependencies(
          classes: content.heroClasses(),
          monsterTemplates: content.monsters(),
          seed: 12345,
        ),
      ),
      runeTreeProvider.overrideWithValue(content.runeTree()),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: const CombatScreen(),
    ),
  );

  testWidgets('a tela de combate abre sem erro', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CombatScreen), findsOneWidget);
  });

  testWidgets('sobrevive a vários quadros com o jogo rodando', (tester) async {
    await tester.pumpWidget(app());

    // Alguns segundos de quadros: tempo suficiente para o motor tickar, a arena
    // sincronizar e o fundo terminar de carregar.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.takeException(),
        isNull,
        reason: 'exceção no quadro $i',
      );
    }
  });

  testWidgets('sobrevive a mudança de tamanho de tela', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));

    // Girar o aparelho: o fundo precisa acompanhar sem estourar.
    await tester.binding.setSurfaceSize(const Size(960, 480));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('a HUD mostra wave, ato e dificuldade desde o primeiro quadro', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();

    // SC-M08-02: os três numa tela só, sem navegação.
    expect(find.textContaining('Wave'), findsWidgets);
    expect(find.textContaining('Ato'), findsWidgets);
    expect(find.textContaining('Dif.'), findsWidgets);
  });
}
