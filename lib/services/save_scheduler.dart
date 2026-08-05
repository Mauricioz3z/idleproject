import 'dart:async';

import '../core/clock/clock.dart';
import '../domain/entities/save_state.dart';
import '../domain/ports/save_repository.dart';

/// Agenda o auto-save de 30 s e a gravação em `onAppPause` (R-M10-01, R-M10-02).
///
/// O intervalo de 30 s vem de `specification.md` §4.5 e define diretamente
/// SC-M10-01: a perda máxima em encerramento inesperado é uma janela de
/// auto-save.
class SaveScheduler {
  SaveScheduler({
    required SaveRepository repository,
    required Clock clock,
    required SaveState Function() snapshot,
    Duration interval = defaultInterval,
    void Function(Object error)? onError,
  }) : _repository = repository,
       _clock = clock,
       _snapshot = snapshot,
       _interval = interval,
       _onError = onError;

  static const Duration defaultInterval = Duration(seconds: 30);

  final SaveRepository _repository;
  final Clock _clock;
  final SaveState Function() _snapshot;
  final Duration _interval;
  final void Function(Object error)? _onError;

  Timer? _timer;
  bool _saving = false;

  bool get isRunning => _timer?.isActive ?? false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => unawaited(saveNow()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Grava imediatamente. Chamado pelo ciclo periódico e por `onAppPause`.
  ///
  /// Reentrância é ignorada em silêncio: duas gravações simultâneas do mesmo
  /// estado não trariam nada e disputariam a seção crítica de promoção
  /// (CEN-M10-E03).
  Future<void> saveNow() async {
    if (_saving) return;
    _saving = true;
    try {
      final state = _snapshot();
      await _repository.save(
        state.copyWith(
          account: state.account.copyWith(lastSaveAt: _clock.now()),
          lastMonotonicMillis: _clock.monotonicMillis(),
        ),
      );
    } on Object catch (e) {
      // Falha ao salvar não pode derrubar o jogo: o commit anterior segue
      // íntegro e o jogador é avisado pela camada acima (CEN-M10-E02).
      _onError?.call(e);
    } finally {
      _saving = false;
    }
  }

  /// Chamado quando o app vai para segundo plano (R-M10-02).
  Future<void> onAppPause() => saveNow();

  void dispose() => stop();
}
