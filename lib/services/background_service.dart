import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:workmanager/workmanager.dart';

/// Identificadores das tarefas (contracts/platform-android.md §3).
abstract final class BackgroundTasks {
  static const String refreshWidget = 'refresh_widget';
  static const String detectRareEvents = 'detect_rare_events';
  static const String foregroundStatus = 'foreground_status';

  /// Piso da plataforma para tarefas periódicas do WorkManager. Não é escolha
  /// de balanceamento: pedir menos não faz o sistema entregar mais.
  static const Duration workManagerFloor = Duration(minutes: 15);

  /// Cadência do serviço em primeiro plano, a única capaz de atender a
  /// R-M11-02 (1 min).
  static const Duration foregroundInterval = Duration(minutes: 1);
}

/// Agendamento de segundo plano (M11).
///
/// **Três restrições que valem para toda tarefa daqui**, do contrato §3:
///
/// 1. Nenhuma executa combate real (§8 de `specification.md`, CEN-M09-010). Elas
///    projetam a partir do save; a resolução verdadeira acontece no
///    `OfflineSimulator` quando o jogador reabre.
/// 2. Nenhuma grava estado de jogo. Só leem o save e escrevem payload de widget
///    e notificações. É o que mantém uma única escritora do save e elimina a
///    corrida de CEN-M10-E03.
/// 3. Fabricantes com economia agressiva de bateria podem suprimir tudo isto.
///    É comportamento aceito (CEN-M11-E02); a recuperação vem do cálculo
///    offline na reabertura.
class BackgroundService {
  const BackgroundService();

  /// Registra o despachante e agenda as tarefas periódicas.
  Future<void> start({required Function callbackDispatcher}) async {
    await Workmanager().initialize(callbackDispatcher);

    await Workmanager().registerPeriodicTask(
      BackgroundTasks.refreshWidget,
      BackgroundTasks.refreshWidget,
      frequency: BackgroundTasks.workManagerFloor,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
      ),
    );

    await Workmanager().registerPeriodicTask(
      BackgroundTasks.detectRareEvents,
      BackgroundTasks.detectRareEvents,
      frequency: BackgroundTasks.workManagerFloor,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
      ),
    );
  }

  Future<void> stop() async {
    await Workmanager().cancelByUniqueName(BackgroundTasks.refreshWidget);
    await Workmanager().cancelByUniqueName(BackgroundTasks.detectRareEvents);
  }

  /// Configura o serviço em primeiro plano de 1 minuto (T106).
  ///
  /// É o **único** caminho que atinge a cadência de R-M11-02. Fora dele, o piso
  /// de 15 min do WorkManager vale, e o widget se mantém correto pela projeção
  /// no desenho, não pela frequência (research.md R4).
  void configureForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'idle_status',
        channelName: 'Status do jogo',
        channelDescription:
            'Wave, ato e ouro por minuto enquanto o jogo roda.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          BackgroundTasks.foregroundInterval.inMilliseconds,
        ),
        autoRunOnBoot: false,
        allowWakeLock: false,
        allowWifiLock: false,
      ),
    );
  }

  /// Inicia a notificação persistente com cadência fina.
  ///
  /// Só é chamado quando o jogador mantém a opção ligada (CEN-M11-010).
  Future<void> startForegroundStatus() async {
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      notificationTitle: 'Pixel Idle Quest',
      notificationText: 'Acompanhando o progresso',
    );
  }

  Future<void> stopForegroundStatus() async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }
}
