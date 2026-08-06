import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notification_providers.dart';

/// Opções do jogo.
///
/// Hoje só a notificação persistente, que é requisito explícito: CEN-M11-010
/// exige poder desligá-la, e SC-M11-04 exige que negar notificações nunca
/// bloqueie progresso. As duas coisas precisam ficar visíveis para o jogador,
/// senão ele desinstala o jogo em vez de desligar o aviso.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final controller = ref.read(notificationSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Opções')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SwitchListTile(
            value: settings.persistentStatusEnabled,
            onChanged: controller.setPersistentStatusEnabled,
            title: const Text('Notificação persistente'),
            subtitle: const Text(
              'Mostra wave, ato e ouro por minuto enquanto o jogo está em '
              'segundo plano.',
              style: TextStyle(fontSize: 11),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Desligar não afeta o progresso: o cálculo offline continua '
              'valendo e os ganhos aparecem no resumo ao abrir o jogo.',
              style: TextStyle(fontSize: 11, color: Color(0xFFB4AAC6)),
            ),
          ),
          if (!settings.permissionGranted) ...[
            const Divider(color: Color(0xFF3A3548)),
            ListTile(
              title: const Text('Notificações bloqueadas pelo sistema'),
              subtitle: const Text(
                'Nada é perdido: os eventos continuam registrados e aparecem '
                'no resumo quando você abre o jogo.',
                style: TextStyle(fontSize: 11),
              ),
              trailing: TextButton(
                onPressed: controller.requestPermission,
                child: const Text('Permitir'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
