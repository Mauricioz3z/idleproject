import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/player_account.dart';
import '../../domain/entitlements/entitlement_service.dart';
import '../../services/ad_service.dart';
import '../providers/combat_providers.dart';
import '../providers/monetization_providers.dart';

/// Loja: ofertas de M12, saldo de gemas e tempo restante do bônus ativo.
///
/// O texto da tela é parte do requisito, não enfeite: R-M12-01 exige que nada
/// aqui seja pré-requisito de progressão, e a única forma de o jogador saber
/// disso é a tela dizer. Nenhuma oferta usa linguagem de urgência ou de
/// bloqueio.
class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(combatControllerProvider);
    final entitlements = session.entitlements;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Loja')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Balance(gems: session.account.gems),
          if (entitlements.isGoldBoostActive(now))
            _ActiveBoost(remaining: entitlements.goldBoostRemaining(now)),
          const SizedBox(height: 12),
          const _SectionTitle('Anúncios recompensados'),
          const _AdOffer(
            title: '+50% de ouro por 4 horas',
            subtitle: 'Com bônus ativo, a duração é estendida.',
            reward: AdReward.goldBoost4h,
          ),
          const _AdOffer(
            title: 'Revive instantâneo',
            subtitle: 'Cancela a espera de 30 s de um herói caído.',
            reward: AdReward.instantRevive,
          ),
          _AdOffer(
            title: '+1 slot de cubo',
            subtitle: 'Slots extras: ${entitlements.extraCubeSlots}',
            reward: AdReward.extraCubeSlot,
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Compras'),
          _PurchaseOffer(
            title: 'Remover anúncios',
            subtitle: entitlements.adsRemoved
                ? 'Já adquirido.'
                : 'Remove os intersticiais. Os recompensados continuam '
                      'disponíveis como opção.',
            id: PurchaseId.removeAds,
            enabled: !entitlements.adsRemoved,
          ),
          _PurchaseOffer(
            title: 'Pacote de Início',
            subtitle: session.account.hasFourthSlot
                ? 'Você já tem o 4º slot.'
                : 'Antecipa o 4º slot de formação — que também chega de graça '
                      'no nível de conta '
                      '${PlayerAccount.fourthSlotUnlockLevel} — mais '
                      '${PlayerAccount.fourthSlotCompensationGems} gemas.',
            id: PurchaseId.starterPack,
            enabled: !session.account.hasFourthSlot,
          ),
          const _PurchaseOffer(
            title: 'Gemas — pacote médio',
            subtitle: 'Gemas aceleram o Cubo e o respec. Não desbloqueiam '
                'nada que o jogo não conceda jogando.',
            id: PurchaseId.gemsMedium,
            enabled: true,
          ),
          const SizedBox(height: 16),
          const _NoPaywallNotice(),
        ],
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.gems});

  final int gems;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF272238),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Text(
            'Gemas',
            style: TextStyle(fontSize: 13, color: Color(0xFFB4AAC6)),
          ),
          const Spacer(),
          Text(
            '$gems',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4AC5E8),
            ),
          ),
        ],
      ),
    );
  }
}

/// CEN-M12-001: o tempo restante do bônus é exibido.
class _ActiveBoost extends StatelessWidget {
  const _ActiveBoost({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final horas = remaining.inHours;
    final minutos = remaining.inMinutes.remainder(60);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: const Color(0xFF2E2740),
      padding: const EdgeInsets.all(10),
      child: Text(
        'Bônus de ouro ativo: +50% por mais '
        '${horas > 0 ? "$horas h " : ""}$minutos min',
        style: const TextStyle(fontSize: 12, color: Color(0xFFE8B44A)),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );
}

class _AdOffer extends ConsumerWidget {
  const _AdOffer({
    required this.title,
    required this.subtitle,
    required this.reward,
  });

  final String title;
  final String subtitle;
  final AdReward reward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF3A3548)),
      ),
      child: ListTile(
        dense: true,
        title: Text(title, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Color(0xFFB4AAC6)),
        ),
        trailing: TextButton(
          onPressed: () => _watch(context, ref),
          child: const Text('Assistir'),
        ),
      ),
    );
  }

  Future<void> _watch(BuildContext context, WidgetRef ref) async {
    final outcome = await ref
        .read(monetizationControllerProvider.notifier)
        .watchRewarded(reward);

    if (!context.mounted || outcome.granted) return;

    // CEN-M12-E01: sem rede, uma mensagem explicativa — e o jogo segue.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (outcome.failure) {
          AdFailure.notLoaded ||
          AdFailure.network =>
            'Nenhum anúncio disponível agora. Tente mais tarde — nada foi '
                'perdido.',
          AdFailure.dismissedEarly =>
            'O anúncio precisa ser assistido por inteiro para conceder a '
                'recompensa.',
          null => 'A recompensa não foi concedida.',
        }),
      ),
    );
  }
}

class _PurchaseOffer extends ConsumerWidget {
  const _PurchaseOffer({
    required this.title,
    required this.subtitle,
    required this.id,
    required this.enabled,
  });

  final String title;
  final String subtitle;
  final PurchaseId id;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF3A3548)),
      ),
      child: ListTile(
        dense: true,
        enabled: enabled,
        title: Text(title, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Color(0xFFB4AAC6)),
        ),
        trailing: enabled
            ? TextButton(
                onPressed: () => _buy(context, ref),
                child: const Text('Comprar'),
              )
            : null,
      ),
    );
  }

  Future<void> _buy(BuildContext context, WidgetRef ref) async {
    final store = ref.read(iapServiceProvider);
    final product = store.products
        .where((p) => p.id == id.storeId)
        .firstOrNull;

    if (product == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loja indisponível agora. Nada foi cobrado.'),
        ),
      );
      return;
    }

    await store.buy(product);
  }
}

/// R-M12-01 dito em voz alta. Uma loja que não afirma isso deixa o jogador
/// deduzir o contrário.
class _NoPaywallNotice extends StatelessWidget {
  const _NoPaywallNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF272238),
      padding: const EdgeInsets.all(12),
      child: const Text(
        'Nada aqui é obrigatório. Todas as waves, atos, dificuldades, '
        'raridades de item, nós de runa e slots de formação são alcançáveis '
        'jogando, sem comprar nem assistir a nada.',
        style: TextStyle(fontSize: 11, color: Color(0xFFB4AAC6)),
      ),
    );
  }
}
