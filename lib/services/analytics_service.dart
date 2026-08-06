import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../data/dto/save_validator.dart';
import '../domain/ports/save_repository.dart';
import '../services/clock_guard.dart';

/// Eventos que o jogo registra.
///
/// Nomes fixos em constantes porque string solta em chamada de analytics é
/// como a metade dos eventos acaba com grafia diferente e some do relatório.
abstract final class AnalyticsEvents {
  static const String saveFailed = 'save_failed';
  static const String saveRepaired = 'save_repaired';
  static const String clockAnomaly = 'clock_anomaly';
  static const String offlineReturn = 'offline_return';
  static const String difficultyUnlocked = 'difficulty_unlocked';
  static const String adRewardGranted = 'ad_reward_granted';
  static const String purchaseApplied = 'purchase_applied';
}

/// Analytics e relatório de falhas (T142).
///
/// **Nada aqui pode alterar o jogo.** Todo método é fire-and-forget e engole a
/// própria exceção: uma falha de telemetria não pode derrubar uma partida nem
/// bloquear um save. É por isso que nenhum método retorna erro.
///
/// Os eventos escolhidos não são genéricos: são exatamente os pontos onde a
/// spec admite comportamento degradado — save que falhou, save que precisou de
/// reparo, relógio inconsistente. São as três coisas que, quando acontecem em
/// campo, ninguém descobre sem telemetria.
class AnalyticsService {
  AnalyticsService({FirebaseAnalytics? analytics, FirebaseCrashlytics? crash})
    : _analytics = analytics,
      _crash = crash;

  FirebaseAnalytics? _analytics;
  FirebaseCrashlytics? _crash;
  bool _initialized = false;

  bool get isEnabled => _initialized;

  /// Liga o Firebase. Sem `firebase_options.dart` configurado, o serviço fica
  /// inerte e o jogo roda igual — é o estado normal em desenvolvimento.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      _analytics ??= FirebaseAnalytics.instance;
      _crash ??= FirebaseCrashlytics.instance;

      // Erros não capturados do Flutter vão para o Crashlytics em release.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        if (!kDebugMode) _crash?.recordFlutterFatalError(details);
      };
      _initialized = true;
    } on Object {
      // Firebase ausente ou mal configurado: seguir sem telemetria.
      _initialized = false;
    }
  }

  /// CEN-M10-E02: a gravação falhou. O jogo continua, e o evento fica
  /// registrado — é a única forma de descobrir que jogadores estão perdendo
  /// progresso por disco cheio.
  void recordSaveFailure(SaveOutcome outcome, Object error) {
    _log(AnalyticsEvents.saveFailed, {'outcome': outcome.name});
    _recordError(error, 'save falhou: ${outcome.name}');
  }

  /// D-01..D-07: o save carregado precisou de reparo. Um pico aqui significa
  /// bug de serialização em produção.
  void recordSaveRepairs(List<SaveRepair> repairs) {
    if (repairs.isEmpty) return;
    _log(AnalyticsEvents.saveRepaired, {
      'count': repairs.length,
      // As regras violadas (`D-01`..`D-07`), não o detalhe: o detalhe pode
      // conter IDs do jogador, e telemetria não é lugar para isso.
      'rules': repairs.map((r) => r.rule).toSet().join(','),
    });
  }

  /// research R7: relógio de parede e monotônico discordaram.
  ///
  /// Registrado, **nunca punido** — o teto de 8 h já neutraliza o ganho, e
  /// fuso horário e horário de verão produzem o mesmo sinal que manipulação.
  void recordClockAnomaly(ClockAnomaly anomaly, Map<String, Object?> data) {
    if (anomaly == ClockAnomaly.none ||
        anomaly == ClockAnomaly.processRestarted) {
      return;
    }
    _log(AnalyticsEvents.clockAnomaly, {'anomaly': anomaly.name, ...data});
  }

  void recordOfflineReturn({
    required int elapsedSeconds,
    required bool wasCapped,
    required int wavesAdvanced,
  }) => _log(AnalyticsEvents.offlineReturn, {
    'elapsed_seconds': elapsedSeconds,
    'was_capped': wasCapped,
    'waves_advanced': wavesAdvanced,
  });

  void recordDifficultyUnlocked(int difficulty) =>
      _log(AnalyticsEvents.difficultyUnlocked, {'difficulty': difficulty});

  void recordAdReward(String reward) =>
      _log(AnalyticsEvents.adRewardGranted, {'reward': reward});

  void recordPurchase(String productId) =>
      _log(AnalyticsEvents.purchaseApplied, {'product_id': productId});

  void _log(String name, Map<String, Object?> parameters) {
    if (!_initialized) return;
    try {
      _analytics?.logEvent(
        name: name,
        parameters: {
          for (final entry in parameters.entries)
            if (entry.value != null) entry.key: entry.value!,
        },
      );
    } on Object {
      // Telemetria nunca interrompe o jogo.
    }
  }

  void _recordError(Object error, String reason) {
    if (!_initialized) return;
    try {
      _crash?.recordError(error, StackTrace.current, reason: reason);
    } on Object {
      // idem
    }
  }
}
