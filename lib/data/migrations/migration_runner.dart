import '../../domain/entities/save_state.dart';

/// Uma migração de schema `v(n) → v(n+1)`.
typedef Migration = Map<String, dynamic> Function(Map<String, dynamic> raw);

/// Save gravado por uma versão do app mais nova que a instalada.
///
/// Não é aberto **nem sobrescrito**: sobrescrever aqui destruiria o progresso
/// de quem tem duas instalações. O jogador é avisado e nada é tocado.
class FutureSchemaException implements Exception {
  const FutureSchemaException(this.found, this.supported);

  final int found;
  final int supported;

  @override
  String toString() =>
      'Save na versão $found, mas este app suporta até $supported. '
      'Atualize o app para abrir este save.';
}

/// Aplica migrações encadeadas na ordem, conforme
/// contracts/persistence-save-schema.md.
///
/// Regra que vale para toda migração: **nunca destruir dado que não sabe
/// interpretar**. Campo desconhecido é preservado como está.
class MigrationRunner {
  MigrationRunner({Map<int, Migration>? migrations})
    : _migrations = migrations ?? _defaultMigrations;

  /// Migrações de produção. Cada chave `n` transforma v(n) em v(n+1).
  ///
  /// Vazio hoje porque v1 é o formato inicial. A primeira mudança
  /// incompatível registra `1: (raw) => ...` aqui, com teste próprio.
  static const Map<int, Migration> _defaultMigrations = {};

  final Map<int, Migration> _migrations;

  int get supportedVersion => SaveState.currentSchemaVersion;

  /// Traz o documento bruto até a versão suportada.
  ///
  /// Lança [FutureSchemaException] para saves de versão futura, e nunca grava
  /// nada — a decisão de escrever é de quem chama.
  Map<String, dynamic> migrate(Map<String, dynamic> raw) {
    var version = (raw['schemaVersion'] as num?)?.toInt() ?? 1;

    if (version > supportedVersion) {
      throw FutureSchemaException(version, supportedVersion);
    }

    var current = raw;
    while (version < supportedVersion) {
      final step = _migrations[version];
      if (step == null) {
        // Sem migração declarada: assume compatibilidade e só marca a versão.
        // O alternativa seria recusar o save, o que custaria o progresso do
        // jogador por uma omissão nossa.
        version++;
        current = {...current, 'schemaVersion': version};
        continue;
      }
      current = step(current);
      version = (current['schemaVersion'] as num?)?.toInt() ?? version + 1;
    }
    return current;
  }
}
