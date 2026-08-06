import 'package:hive/hive.dart';

import '../../domain/entities/save_state.dart';
import '../../domain/ports/save_repository.dart';
import '../dto/save_codec.dart';
import '../dto/save_validator.dart';
import '../migrations/migration_runner.dart';

/// Persistência local em Hive, com gravação atômica.
///
/// `specification.md` §4.5 fixa auto-save de 30 s e gravação em `onAppPause`,
/// e CEN-M10-007 exige que save corrompido nunca substitua save válido — o que
/// gravação direta em box não garante sozinha.
///
/// Protocolo (contracts/persistence-save-schema.md): grava no documento
/// pendente, dá flush, marca `committedVersion`, promove. Na carga, se a marca
/// não bater com o pendente, o pendente é descartado e o último commit válido
/// é carregado.
class HiveSaveRepository implements SaveRepository {
  HiveSaveRepository({
    required Box<dynamic> metaBox,
    required Box<dynamic> saveBox,
    MigrationRunner? migrations,
    Set<String>? knownRuneNodeIds,
    void Function(List<SaveRepair>)? onRepairs,
  }) : _meta = metaBox,
       _box = saveBox,
       _migrations = migrations ?? MigrationRunner(),
       _knownRuneNodeIds = knownRuneNodeIds,
       _onRepairs = onRepairs;

  static const String _committedKey = 'committed';
  static const String _pendingKey = 'pending';
  static const String _committedVersionKey = 'committedVersion';

  final Box<dynamic> _meta;
  final Box<dynamic> _box;
  final MigrationRunner _migrations;
  final Set<String>? _knownRuneNodeIds;
  final void Function(List<SaveRepair>)? _onRepairs;

  /// Último resultado de gravação, para que a camada de aplicação possa avisar
  /// o jogador em vez de falhar em silêncio (CEN-M10-E02).
  SaveOutcome lastOutcome = SaveOutcome.committed;

  @override
  Future<SaveState?> load() async {
    final committed = _box.get(_committedKey);
    if (committed == null) return null; // primeira execução

    final raw = Map<String, dynamic>.from(committed as Map);
    final migrated = _migrations.migrate(raw);
    final decoded = SaveCodec.decodeSave(migrated);
    final validated = SaveValidator.validate(
      decoded,
      knownRuneNodeIds: _knownRuneNodeIds,
    );

    if (!validated.isClean) _onRepairs?.call(validated.repairs);
    return validated.state;
  }

  @override
  Future<void> save(SaveState state) async {
    final encoded = SaveCodec.encodeSave(state);
    try {
      // 1. escreve o pendente e força para o disco
      await _box.put(_pendingKey, encoded);
      await _box.flush();

      // 2. marca a versão pretendida
      final stamp = DateTime.now().microsecondsSinceEpoch;
      await _meta.put(_committedVersionKey, stamp);
      await _meta.flush();

      // 3. promove. Só depois deste ponto o save anterior deixa de valer.
      await _box.put(_committedKey, encoded);
      await _box.flush();
      await _box.delete(_pendingKey);

      lastOutcome = SaveOutcome.committed;
    } on Object catch (e) {
      // O commit anterior permanece íntegro — é o ponto do protocolo.
      lastOutcome = _classify(e);
      await _discardPending();
      rethrow;
    }
  }

  /// Descarta o documento pendente depois de uma gravação malsucedida.
  ///
  /// Sem isto, um disco cheio fica **pior a cada tentativa**: o pendente
  /// parcial continua ocupando espaço, e o auto-save de 30 s tenta de novo com
  /// menos espaço do que tinha antes. O commit anterior nunca é tocado — é ele
  /// que sustenta CEN-M10-007 —, então limpar o pendente é sempre seguro.
  ///
  /// A limpeza também pode falhar, e falhar aqui não pode escalar: o erro que
  /// interessa ao jogador é o da gravação, não o da faxina.
  Future<void> _discardPending() async {
    try {
      if (_box.containsKey(_pendingKey)) {
        await _box.delete(_pendingKey);
        await _box.flush();
      }
    } on Object {
      // Espaço insuficiente até para apagar. Nada mais a fazer aqui.
    }
  }

  @override
  Future<void> clear() async {
    await _box.clear();
    await _meta.clear();
  }

  static SaveOutcome _classify(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('no space') ||
        text.contains('disk full') ||
        text.contains('enospc')) {
      return SaveOutcome.failedStorageFull;
    }
    return SaveOutcome.failedUnknown;
  }
}
