import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock/clock.dart';
import '../../core/rng/rng_stream.dart';
import '../../domain/engines/combat_engine.dart';
import '../../domain/engines/offline_simulator.dart';
import '../../domain/entities/offline_report.dart';
import '../../domain/entities/save_state.dart';
import '../../domain/ports/save_repository.dart';
import '../../services/analytics_service.dart';
import '../../services/clock_guard.dart';
import 'combat_providers.dart';
import 'wave_providers.dart';

final clockProvider = Provider<Clock>((ref) => SystemClock());

/// Repositório de save. Sobrescrito no `ProviderScope` com a implementação
/// Hive; sem sobrescrita, o jogo roda sem persistir — o que é o comportamento
/// certo em teste, não em produção.
final saveRepositoryProvider = Provider<SaveRepository?>((ref) => null);

final offlineSimulatorProvider = Provider<OfflineSimulator>(
  (ref) => const OfflineSimulator(),
);

final analyticsProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(),
);

final clockGuardProvider = Provider<ClockGuard>(
  (ref) => ClockGuard(
    clock: ref.watch(clockProvider),
    // Observação, não punição: o teto de 8 h já neutraliza o ganho, e fuso
    // horário produz o mesmo sinal que manipulação (research.md R7).
    onAnomaly: (anomaly, data) =>
        ref.read(analyticsProvider).recordClockAnomaly(anomaly, data),
  ),
);

/// Estado da retomada: o resumo pendente e se o combate pode rodar.
class OfflineState {
  const OfflineState({
    required this.report,
    required this.isBooting,
    required this.anomaly,
  });

  factory OfflineState.initial() => const OfflineState(
    report: null,
    isBooting: true,
    anomaly: ClockAnomaly.none,
  );

  /// Resumo aguardando ser dispensado. `null` quando não há o que mostrar.
  final OfflineReport? report;

  /// Verdadeiro até o boot resolver a carga do save.
  final bool isBooting;

  final ClockAnomaly anomaly;

  /// CEN-M09-005: o combate ao vivo só retoma depois que o jogador dispensa o
  /// resumo. Enquanto houver relatório pendente, o game loop fica parado.
  bool get blocksCombat => isBooting || report != null;

  OfflineState copyWith({
    OfflineReport? report,
    bool clearReport = false,
    bool? isBooting,
    ClockAnomaly? anomaly,
  }) => OfflineState(
    report: clearReport ? null : (report ?? this.report),
    isBooting: isBooting ?? this.isBooting,
    anomaly: anomaly ?? this.anomaly,
  );
}

/// Liga a simulação offline ao boot e ao retorno de segundo plano (T096).
class OfflineController extends Notifier<OfflineState> {
  @override
  OfflineState build() => OfflineState.initial();

  /// Carrega o save, resolve a ausência e adota o resultado.
  ///
  /// Chamado uma vez na abertura. Sem save gravado, é primeira execução: nada é
  /// simulado e nenhum resumo aparece (CEN-M09-E03).
  Future<void> boot() async {
    final repository = ref.read(saveRepositoryProvider);
    if (repository == null) {
      state = state.copyWith(isBooting: false);
      return;
    }

    SaveState? saved;
    try {
      saved = await repository.load();
    } on Object {
      // Save ilegível já foi tratado pelo repositório, que devolve o último
      // commit íntegro ou nada. Aqui só resta seguir com jogo novo.
      saved = null;
    }

    if (saved == null) {
      state = state.copyWith(isBooting: false);
      return;
    }

    _applyAbsence(saved);
    state = state.copyWith(isBooting: false);
  }

  /// Retorno de segundo plano. O app não roda combate fechado (R-M09-07), então
  /// o intervalo é resolvido aqui, do mesmo jeito que no boot.
  void onResumeFromBackground() {
    if (state.isBooting) return;
    final clock = ref.read(clockProvider);
    // Sem `now`: a ausência é medida a partir do último save, e carimbar o
    // instante atual apagaria o intervalo que se quer simular.
    _applyAbsence(
      ref
          .read(combatControllerProvider.notifier)
          .snapshot(monotonicMillis: clock.monotonicMillis()),
    );
  }

  /// Dispensa o resumo e libera o combate (CEN-M09-005).
  void dismissReport() => state = state.copyWith(clearReport: true);

  void _applyAbsence(SaveState saved) {
    final guard = ref.read(clockGuardProvider);
    final reading = guard.evaluate(
      lastSaveAt: saved.account.lastSaveAt,
      lastMonotonicMillis: saved.lastMonotonicMillis,
    );

    final deps = ref.read(combatDependenciesProvider);
    final simulation = ref.read(offlineSimulatorProvider).simulate(
      state: saved,
      now: reading.now,
      combat: CombatEngine(rng: RngStream(seed: saved.account.rngSeed)),
      waves: ref.read(waveDirectorProvider),
      classes: deps.classes,
    );

    ref.read(combatControllerProvider.notifier).restore(simulation.state);

    if (!simulation.report.isEmpty) {
      ref.read(analyticsProvider).recordOfflineReturn(
        elapsedSeconds: simulation.report.elapsedSeconds,
        wasCapped: simulation.report.wasCapped,
        wavesAdvanced: simulation.report.wavesAdvanced,
      );
    }

    state = state.copyWith(
      // Relatório vazio não vira tela: o jogador que fechou o app por dez
      // segundos não quer um resumo de dez segundos (CEN-M09-E03).
      report: simulation.report.isEmpty ? null : simulation.report,
      clearReport: simulation.report.isEmpty,
      anomaly: reading.anomaly,
    );
  }
}

final offlineControllerProvider =
    NotifierProvider<OfflineController, OfflineState>(OfflineController.new);
