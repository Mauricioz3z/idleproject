import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/numeric/number_format.dart';
import '../domain/engines/state_projector.dart';

/// Canais de notificação (contracts/platform-android.md §2).
///
/// Três, e não um, porque a importância difere: o status persistente não pode
/// tocar som a cada minuto, e um lendário caindo merece chamar atenção. Canal é
/// a única forma de o Android deixar o **jogador** decidir isso por categoria.
abstract final class NotificationChannels {
  static const String status = 'idle_status';
  static const String loot = 'idle_loot';
  static const String inventory = 'idle_inventory';
}

/// Ações da notificação persistente (R-M11-07).
abstract final class NotificationActions {
  static const String open = 'open';
  static const String collectLoot = 'collect_loot';
}

/// Notificações do jogo (M11).
///
/// **Permissão negada nunca bloqueia progresso** (SC-M11-04, CEN-M11-E01): os
/// métodos falham em silêncio e os eventos continuam registrados, aparecendo no
/// resumo quando o jogador abrir o app. É por isso que nada aqui retorna erro
/// para o domínio.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const int statusNotificationId = 1;
  static const int lootNotificationId = 2;
  static const int inventoryNotificationId = 3;

  bool _initialized = false;
  bool _permitted = false;
  bool _statusEnabled = true;

  /// Verdadeiro quando o sistema autorizou notificações.
  bool get isPermitted => _permitted;

  /// CEN-M11-010: o jogador pode desligar a persistente sem perder progresso.
  bool get isStatusEnabled => _statusEnabled;

  Future<void> initialize({
    void Function(String? payload)? onTap,
  }) async {
    if (_initialized) return;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          onTap?.call(response.payload),
    );

    await _createChannels();
    _initialized = true;
  }

  /// Pede `POST_NOTIFICATIONS` (Android 13+).
  ///
  /// A recusa é registrada e o jogo segue: nenhuma recompensa depende disso.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return _permitted = false;

    _permitted = await android.requestNotificationsPermission() ?? false;
    return _permitted;
  }

  Future<void> _createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.status,
        'Status do jogo',
        description: 'Wave, ato e ouro por minuto enquanto o jogo roda.',
        // Baixa de propósito: uma notificação que atualiza a cada minuto e
        // emite som seria desinstalada no primeiro dia.
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.loot,
        'Itens raros',
        description: 'Avisa quando cai um item lendário ou superior.',
        importance: Importance.defaultImportance,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.inventory,
        'Inventário',
        description: 'Avisa quando o inventário fica cheio.',
        importance: Importance.defaultImportance,
      ),
    );
  }

  /// Liga ou desliga a persistente (CEN-M11-010).
  Future<void> setStatusEnabled(bool enabled) async {
    _statusEnabled = enabled;
    if (!enabled) await dismissStatus();
  }

  /// Notificação persistente com o estado projetado (R-M11-06).
  Future<void> showStatus(ProjectedState projection) async {
    if (!_canNotify || !_statusEnabled || !projection.hasSave) return;

    final position = projection.position!;
    final title =
        'Pixel Idle Quest — Wave ${position.globalWave} (Ato ${position.act})';
    final body =
        '${projection.heroesInFormation} heróis em combate | '
        '${NumberFormat.compact(projection.goldPerMinute)} ouro/min';

    await _plugin.show(
      id: statusNotificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.status,
          'Status do jogo',
          importance: Importance.low,
          priority: Priority.low,
          // Persistente e silenciosa: o jogador não pode dispensá-la por
          // engano, e ela não interrompe nada.
          ongoing: true,
          silent: true,
          showWhen: false,
          actions: [
            AndroidNotificationAction(
              NotificationActions.open,
              'Abrir',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              NotificationActions.collectLoot,
              'Coletar Loot',
              showsUserInterface: true,
            ),
          ],
        ),
      ),
      // As duas ações abrem o app; nenhuma concede recompensa por si
      // (R-M11-07). O destino muda, o efeito não.
      payload: 'pixelidle://combat',
    );
  }

  Future<void> dismissStatus() => _plugin.cancel(id: statusNotificationId);

  /// CEN-M11-007: item lendário ou superior obtido durante a ausência.
  Future<void> notifyRareLoot({
    required String rarityId,
    required String itemLabel,
  }) async {
    if (!_canNotify) return;

    await _plugin.show(
      id: lootNotificationId,
      title: 'Item $rarityId encontrado',
      body: itemLabel,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.loot,
          'Itens raros',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: 'pixelidle://inventory',
    );
  }

  /// CEN-M11-008: inventário cheio, com drops retidos.
  Future<void> notifyInventoryFull() async {
    if (!_canNotify) return;

    await _plugin.show(
      id: inventoryNotificationId,
      title: 'Inventário cheio',
      body: 'Novos itens estão retidos até você abrir espaço.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.inventory,
          'Inventário',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: 'pixelidle://inventory',
    );
  }

  bool get _canNotify => _initialized && _permitted;
}
