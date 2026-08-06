import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/hero_class_definition.dart';
import '../../domain/entities/monster_template.dart';

/// Dependências injetáveis dos controladores, para permitir teste sem
/// plataforma.
///
/// Vive num arquivo próprio, e não junto do controlador de combate, porque os
/// três controladores — combate, loot e waves — dependem dela. Mantê-la ao lado
/// de um deles criaria um ciclo de importação entre providers.
class CombatDependencies {
  const CombatDependencies({
    required this.classes,
    required this.monsterTemplates,
    required this.seed,
    this.onProgressChanged,
  });

  final List<HeroClassDefinition> classes;
  final List<MonsterTemplate> monsterTemplates;
  final int seed;

  /// Notificado quando há progresso digno de gravação. É o gancho do auto-save
  /// de 30 s (T031) — o controlador não conhece Hive.
  final void Function()? onProgressChanged;
}

final combatDependenciesProvider = Provider<CombatDependencies>((ref) {
  throw UnimplementedError(
    'Sobrescreva combatDependenciesProvider no ProviderScope com o conteúdo '
    'carregado do ContentRepository.',
  );
});
