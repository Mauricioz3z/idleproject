import '../entities/save_state.dart';

/// Porta de persistência. O domínio declara; `lib/data/` implementa.
///
/// É essa inversão que permite rodar o núcleo inteiro em teste sem Hive e sem
/// Android (plan.md, Structure Decision).
abstract interface class SaveRepository {
  /// Carrega o último save **válido**. Retorna `null` na primeira execução.
  ///
  /// Um save corrompido nunca é retornado: a implementação recorre ao último
  /// commit íntegro (CEN-M10-007).
  Future<SaveState?> load();

  /// Grava de forma atômica. Ou o novo estado é integralmente promovido, ou o
  /// anterior permanece — nunca um meio-termo.
  Future<void> save(SaveState state);

  /// Apaga tudo. Usado apenas por ferramentas de desenvolvimento e teste.
  Future<void> clear();
}

/// Resultado de uma tentativa de gravação, para que a camada de aplicação possa
/// avisar o jogador em vez de falhar em silêncio (CEN-M10-E02).
enum SaveOutcome { committed, failedStorageFull, failedUnknown }
