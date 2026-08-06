import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/background_service.dart';
import '../../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final backgroundServiceProvider = Provider<BackgroundService>(
  (ref) => const BackgroundService(),
);

/// Preferências de notificação do jogador.
class NotificationSettings {
  const NotificationSettings({
    required this.persistentStatusEnabled,
    required this.permissionGranted,
  });

  /// Ligada por padrão: é o diferencial declarado do produto
  /// (`specification.md` §3.1). Desligar é escolha do jogador (CEN-M11-010).
  factory NotificationSettings.initial() => const NotificationSettings(
    persistentStatusEnabled: true,
    permissionGranted: false,
  );

  final bool persistentStatusEnabled;
  final bool permissionGranted;

  NotificationSettings copyWith({
    bool? persistentStatusEnabled,
    bool? permissionGranted,
  }) => NotificationSettings(
    persistentStatusEnabled:
        persistentStatusEnabled ?? this.persistentStatusEnabled,
    permissionGranted: permissionGranted ?? this.permissionGranted,
  );
}

/// Controla a notificação persistente e o serviço em primeiro plano que a
/// sustenta.
///
/// Desligar derruba o serviço de 1 min junto: manter o serviço vivo só para não
/// mostrar nada gastaria bateria sem entregar nada — e a spec permite que o
/// widget caia para a cadência de 15 min nesse caso (research.md R4).
class NotificationSettingsController extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() => NotificationSettings.initial();

  Future<void> requestPermission() async {
    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermission();
    state = state.copyWith(permissionGranted: granted);
  }

  Future<void> setPersistentStatusEnabled(bool enabled) async {
    state = state.copyWith(persistentStatusEnabled: enabled);

    final notifications = ref.read(notificationServiceProvider);
    final background = ref.read(backgroundServiceProvider);

    await notifications.setStatusEnabled(enabled);
    if (enabled) {
      await background.startForegroundStatus();
    } else {
      await background.stopForegroundStatus();
    }
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsController, NotificationSettings>(
      NotificationSettingsController.new,
    );
