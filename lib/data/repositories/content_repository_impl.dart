import 'dart:convert';

import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';
import '../../domain/entities/hero_class_definition.dart';
import '../../domain/entities/monster_template.dart';
import '../../domain/entities/rune_node.dart';
import '../../domain/entities/stats.dart';
import '../../domain/ports/content_repository.dart';

/// Carrega e **valida** o conteúdo estático no boot.
///
/// A validação é agressiva de propósito (research.md R8): árvore com menos de
/// 200 nós, aresta não recíproca ou nó inalcançável são erros de dados do
/// desenvolvedor. Falhar alto no boot os leva para o teste T112; deixar passar
/// os leva para o jogador.
class JsonContentRepository implements ContentRepository {
  JsonContentRepository._({
    required List<HeroClassDefinition> heroClasses,
    required List<MonsterTemplate> monsters,
    required RuneTreeDefinition runeTree,
  }) : _heroClasses = heroClasses,
       _monsters = monsters,
       _runeTree = runeTree,
       _classesById = {for (final c in heroClasses) c.id: c};

  /// Constrói a partir do conteúdo JSON cru e valida.
  ///
  /// Lança [ContentValidationException] com **todos** os problemas de uma vez,
  /// em vez de um por execução.
  /// [requireFullRuneTree] permite carregar conteúdo antes de a árvore de runas
  /// estar autorada (T123, US6). A validação de adjacência e alcançabilidade
  /// continua valendo em qualquer caso — só o mínimo de 200 nós é dispensado,
  /// porque exigi-lo bloquearia US1 por uma dependência de US6.
  factory JsonContentRepository.fromJson({
    required String heroClassesJson,
    required String monstersJson,
    required String runeTreeJson,
    bool requireFullRuneTree = true,
  }) {
    final problems = <String>[];

    final heroClasses = _parseHeroClasses(heroClassesJson, problems);
    final monsters = _parseMonsters(monstersJson, problems);
    final runeTree = _parseRuneTree(runeTreeJson, problems);

    if (requireFullRuneTree && !runeTree.hasMinimumNodes) {
      problems.add(
        'V-RN-01: árvore de runas tem ${runeTree.nodes.length} nós, '
        'mínimo é ${RuneTreeDefinition.minimumNodes}',
      );
    }
    problems.addAll(
      runeTree.findAsymmetricEdges().map((p) => 'V-RN-02: $p'),
    );
    final unreachable = runeTree.findUnreachableNodes();
    if (unreachable.isNotEmpty) {
      problems.add(
        'V-RN-03: ${unreachable.length} nó(s) inalcançável(is) a partir de uma '
        'raiz: ${unreachable.take(5).join(", ")}'
        '${unreachable.length > 5 ? "..." : ""}',
      );
    }

    if (problems.isNotEmpty) throw ContentValidationException(problems);

    return JsonContentRepository._(
      heroClasses: heroClasses,
      monsters: monsters,
      runeTree: runeTree,
    );
  }

  final List<HeroClassDefinition> _heroClasses;
  final List<MonsterTemplate> _monsters;
  final RuneTreeDefinition _runeTree;
  final Map<String, HeroClassDefinition> _classesById;

  @override
  List<HeroClassDefinition> heroClasses() => List.unmodifiable(_heroClasses);

  @override
  HeroClassDefinition? heroClassById(String id) => _classesById[id];

  @override
  List<MonsterTemplate> monsters() => List.unmodifiable(_monsters);

  @override
  List<MonsterTemplate> monstersForAct(int act) =>
      _monsters.where((m) => m.act == act).toList();

  @override
  RuneTreeDefinition runeTree() => _runeTree;

  // -------------------------------------------------------------- parsing

  static Stats _parseStats(Map<String, dynamic> raw) => Stats(
    str: GameNumber.fromDouble((raw['str'] as num?)?.toDouble() ?? 0),
    dex: GameNumber.fromDouble((raw['dex'] as num?)?.toDouble() ?? 0),
    intel: GameNumber.fromDouble((raw['int'] as num?)?.toDouble() ?? 0),
    vit: GameNumber.fromDouble((raw['vit'] as num?)?.toDouble() ?? 0),
    agi: GameNumber.fromDouble((raw['agi'] as num?)?.toDouble() ?? 0),
    attack: GameNumber.fromDouble((raw['attack'] as num?)?.toDouble() ?? 0),
    defense: GameNumber.fromDouble((raw['defense'] as num?)?.toDouble() ?? 0),
    maxHp: GameNumber.fromDouble((raw['maxHp'] as num?)?.toDouble() ?? 0),
  );

  static List<HeroClassDefinition> _parseHeroClasses(
    String json,
    List<String> problems,
  ) {
    final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    return [
      for (final raw in list)
        HeroClassDefinition(
          id: raw['id'] as String,
          displayName: raw['displayName'] as String,
          role: HeroRole.values.firstWhere(
            (r) => r.name == raw['role'],
            orElse: () {
              problems.add('classe ${raw['id']}: papel "${raw['role']}" inválido');
              return HeroRole.tank;
            },
          ),
          primaryStats: ((raw['primaryStats'] as List?) ?? const [])
              .cast<String>(),
          targetingRule: TargetingRule.values.firstWhere(
            (t) => t.name == raw['targetingRule'],
            orElse: () => TargetingRule.nearest,
          ),
          mechanic: ClassMechanic.values.firstWhere(
            (m) => m.name == raw['mechanic'],
            orElse: () {
              problems.add(
                'classe ${raw['id']}: mecânica "${raw['mechanic']}" inválida',
              );
              return ClassMechanic.taunt;
            },
          ),
          baseStats: _parseStats(
            (raw['baseStats'] as Map?)?.cast<String, dynamic>() ?? const {},
          ),
          statGrowthPerLevel: _parseStats(
            (raw['statGrowthPerLevel'] as Map?)?.cast<String, dynamic>() ??
                const {},
          ),
          attacksPerSecond:
              (raw['attacksPerSecond'] as num?)?.toDouble() ?? 1.0,
          skills: [
            for (final s in (raw['skills'] as List?) ?? const [])
              SkillDefinition(
                id: (s as Map)['id'] as String,
                displayName: s['displayName'] as String,
                unlockLevel: (s['unlockLevel'] as num).toInt(),
              ),
          ],
        ),
    ];
  }

  static List<MonsterTemplate> _parseMonsters(
    String json,
    List<String> problems,
  ) {
    final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    return [
      for (final raw in list)
        MonsterTemplate(
          id: raw['id'] as String,
          displayName: raw['displayName'] as String,
          act: (raw['act'] as num?)?.toInt() ?? 1,
          baseStats: _parseStats(
            (raw['baseStats'] as Map?)?.cast<String, dynamic>() ?? const {},
          ),
          possibleRarities: [
            for (final r in (raw['possibleRarities'] as List?) ?? const [])
              ItemRarity.fromId(r as String),
          ],
          dropChanceModifier:
              (raw['dropChanceModifier'] as num?)?.toDouble() ?? 1.0,
          essenceChanceModifier:
              (raw['essenceChanceModifier'] as num?)?.toDouble() ?? 1.0,
          isBoss: raw['isBoss'] as bool? ?? false,
        ),
    ];
  }

  static RuneTreeDefinition _parseRuneTree(
    String json,
    List<String> problems,
  ) {
    final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    return RuneTreeDefinition(
      nodes: [
        for (final raw in list)
          RuneNode(
            id: raw['id'] as String,
            cost: (raw['cost'] as num?)?.toInt() ?? 1,
            neighborIds: ((raw['neighborIds'] as List?) ?? const [])
                .cast<String>(),
            isRoot: raw['isRoot'] as bool? ?? false,
            effect: RuneEffect(
              type:
                  RuneEffectType.fromId(
                    ((raw['effect'] as Map?)?['type'] as String?) ?? '',
                  ) ??
                  () {
                    problems.add(
                      'nó ${raw['id']}: tipo de efeito desconhecido',
                    );
                    return RuneEffectType.damagePercent;
                  }(),
              value:
                  ((raw['effect'] as Map?)?['value'] as num?)?.toDouble() ?? 0,
            ),
          ),
      ],
    );
  }
}
