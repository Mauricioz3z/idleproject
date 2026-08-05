import '../entities/hero_class_definition.dart';
import '../entities/monster_template.dart';
import '../entities/rune_node.dart';

/// Porta de conteúdo estático: classes, monstros e árvore de runas.
///
/// Conteúdo é imutável e vem de assets — não é estado do jogador e não passa
/// pelo save (research.md R8).
abstract interface class ContentRepository {
  List<HeroClassDefinition> heroClasses();
  HeroClassDefinition? heroClassById(String id);

  List<MonsterTemplate> monsters();
  List<MonsterTemplate> monstersForAct(int act);

  RuneTreeDefinition runeTree();
}

/// Erro de conteúdo detectado na validação de boot.
///
/// Estes são erros de dados do desenvolvedor, não do jogador: falham alto e
/// cedo, para aparecerem em teste (T112) e não em produção.
class ContentValidationException implements Exception {
  ContentValidationException(this.problems);

  final List<String> problems;

  @override
  String toString() =>
      'Conteúdo inválido:\n${problems.map((p) => '  - $p').join('\n')}';
}
