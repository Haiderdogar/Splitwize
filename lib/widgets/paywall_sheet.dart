import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/monetization_providers.dart';
import '../utils/monetization.dart';

/// Shows the Ad-Free sheet: what the subscription removes, the two
/// plans (monthly / yearly) and the subscribe / restore actions.
/// Opened from the Profile tab.
Future<void> showPaywallSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PaywallSheet(),
    );

class PaywallSheet extends StatelessWidget {
  const PaywallSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.block_outlined, size: 48, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              'Splitwize Ad-Free',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final isAdFree = ref.watch(adFreeStatusProvider).value ?? false;
                return Text(
                  isAdFree
                      ? 'Ad-Free is active — no ads anywhere. Enjoy!'
                      : 'One subscription removes every ad in the app. '
                          'Everything else stays free.',
                  textAlign: TextAlign.center,
                );
              },
            ),
            const SizedBox(height: 20),
            const _PerkRow(
              icon: Icons.block_outlined,
              text: 'No ads, anywhere in the app',
            ),
            const SizedBox(height: 10),
            const _PerkRow(
              icon: Icons.check_circle_outline,
              text: 'Bills, groups and receipt photos stay free and unlimited',
            ),
            const SizedBox(height: 20),
            Consumer(
              builder: (context, ref, _) {
                final isAdFree = ref.watch(adFreeStatusProvider).value ?? false;
                if (isAdFree) return const SizedBox.shrink();
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PlanSelector(),
                    SizedBox(height: 12),
                    Text(
                      'Billed through your store account. Cancel anytime.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    _SubscribeButton(),
                    _RestoreButton(),
                  ],
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

/// The two plan cards; the selection lives in [PaywallPlan] so the
/// subscribe button and the cards never disagree.
class _PlanSelector extends StatelessWidget {
  const _PlanSelector();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final yearly = ref.watch(paywallPlanProvider);
        final prices = ref.watch(adFreePricesProvider).value ??
            (
              monthly: Monetization.monthlyPriceFallback,
              yearly: Monetization.yearlyPriceFallback,
            );
        return Column(
          children: [
            _PlanCard(
              title: 'Yearly',
              price: prices.yearly,
              badge: 'Best value',
              selected: yearly,
              onTap: () => ref.read(paywallPlanProvider.notifier).select(true),
            ),
            const SizedBox(height: 10),
            _PlanCard(
              title: 'Monthly',
              price: prices.monthly,
              selected: !yearly,
              onTap: () => ref.read(paywallPlanProvider.notifier).select(false),
            ),
          ],
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String price;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? scheme.primary : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(price, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              if (badge != null)
                Chip(
                  label: Text(badge!),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final busy = ref.watch(purchaseBusyProvider);
        return FilledButton(
          onPressed: busy
              ? null
              : () async {
                  final yearly = ref.read(paywallPlanProvider);
                  ref.read(purchaseBusyProvider.notifier).set(true);
                  final outcome = await ref
                      .read(adFreeStatusProvider.notifier)
                      .purchase(yearly: yearly);
                  ref.read(purchaseBusyProvider.notifier).set(false);
                  if (!context.mounted) return;
                  switch (outcome) {
                    case PurchaseOutcome.success:
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Welcome to Ad-Free — no more ads.')),
                      );
                    case PurchaseOutcome.notConfigured:
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Checkout opens with the store launch.')),
                      );
                    case PurchaseOutcome.failed:
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Purchase didn\'t complete. Please try again.')),
                      );
                    case PurchaseOutcome.cancelled:
                      break;
                  }
                },
          child: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Subscribe'),
        );
      },
    );
  }
}

class _RestoreButton extends StatelessWidget {
  const _RestoreButton();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final busy = ref.watch(purchaseBusyProvider);
        return TextButton(
          onPressed: busy
              ? null
              : () async {
                  ref.read(purchaseBusyProvider.notifier).set(true);
                  final outcome =
                      await ref.read(adFreeStatusProvider.notifier).restore();
                  ref.read(purchaseBusyProvider.notifier).set(false);
                  if (!context.mounted) return;
                  if (outcome == PurchaseOutcome.success) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ad-Free restored.')),
                    );
                  } else if (outcome == PurchaseOutcome.notConfigured) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Checkout opens with the store launch.')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('No active subscription found.')),
                    );
                  }
                },
          child: const Text('Restore purchase'),
        );
      },
    );
  }
}
