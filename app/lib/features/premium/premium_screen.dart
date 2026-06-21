import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';
import 'plans.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  Tier _tier = Subscriptions.plus; // entry tier selected by default
  Billing _billing = Billing.monthly; // default to the smaller monthly price
  bool _busy = false;

  /// Buy the selected tier+billing directly from the current offering — this
  /// screen IS the paywall, so there's no RC-hosted paywall step. On success,
  /// `premiumProvider` flips automatically from the customer-info listener.
  Future<void> _purchase() async {
    final productId = _tier.plan(_billing).id;
    setState(() => _busy = true);
    final res = await ref.read(purchasesServiceProvider).purchaseProduct(productId);
    await ref.read(customerInfoProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('You\'re all set. Welcome!')));
      Navigator.of(context).maybePop();
    } else if (!res.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Purchase could not be completed. Please try again.')));
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    await ref.read(purchasesServiceProvider).restore();
    await ref.read(customerInfoProvider.notifier).refresh();
    if (!mounted) return;
    final restored = ref.read(premiumProvider);
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(restored
            ? 'Purchases restored.'
            : 'No previous purchases to restore.')));
    if (restored) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plan = _tier.plan(_billing);
    return Scaffold(
      appBar: AppBar(title: const Text('Go premium'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // Hero card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: t.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Image.asset('assets/illustrations/premium.png',
                      width: 132, height: 132, fit: BoxFit.contain),
                  const SizedBox(height: 12),
                  Text('Choose your plan',
                      style: theme.textTheme.titleLarge?.copyWith(color: t.onPrimarySoft)),
                  const SizedBox(height: 6),
                  Text('Cancel anytime.', style: TextStyle(color: t.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Billing period toggle
            _BillingToggle(
              billing: _billing,
              tokens: t,
              onChanged: (b) => setState(() => _billing = b),
            ),
            const SizedBox(height: 14),
            // Tier selector — Plus / Unlimited
            for (final tier in Subscriptions.tiers) ...[
              _TierCard(
                tier: tier,
                plan: tier.plan(_billing),
                selected: _tier.name == tier.name,
                onTap: () => setState(() => _tier = tier),
                tokens: t,
              ),
              if (tier.valueNote != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(Icons.info_outline, size: 12, color: t.textMuted),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(tier.valueNote!,
                            style: TextStyle(
                                color: t.textMuted, fontSize: 10.5, fontWeight: FontWeight.w500, height: 1.3)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text("What's included in ${_tier.name}",
                  style: TextStyle(color: t.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            // Feature list — checks reflect the SELECTED tier; locked rows show
            // the tier that unlocks them.
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < Subscriptions.features.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: t.border),
                    _FeatureRow(feature: Subscriptions.features[i], selectedRank: _tier.rank),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _purchase,
              child: _busy
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Get ${_tier.name} for ${plan.price}${plan.period}'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _restore,
              child: const Text('Restore purchases'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented Monthly / Annual switch. Annual carries a small "2 months free" hint.
class _BillingToggle extends StatelessWidget {
  final Billing billing;
  final AppTokens tokens;
  final ValueChanged<Billing> onChanged;
  const _BillingToggle({required this.billing, required this.tokens, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget seg(String label, Billing value, {String? badge}) {
      final on = billing == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            // scaleDown so the label + "2 months free" badge never overflow the
            // segment at large system font scales (they scale to fit instead).
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: on ? scheme.onPrimary : tokens.textMuted)),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Text(badge,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: on ? scheme.onPrimary.withValues(alpha: 0.85) : scheme.primary)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        seg('Monthly', Billing.monthly),
        seg('Annual', Billing.annual, badge: '2 months free'),
      ]),
    );
  }
}

/// One selectable subscription tier showing its price for the chosen billing
/// period, with a radio-style state and an optional savings badge.
class _TierCard extends StatelessWidget {
  final Tier tier;
  final Plan plan;
  final bool selected;
  final VoidCallback onTap;
  final AppTokens tokens;
  const _TierCard({
    required this.tier,
    required this.plan,
    required this.selected,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // At large system font sizes the side-by-side price column eats half the
    // card and crushes the feature text to one word per line. Past ~1.5x, stack
    // the price below the details instead so both stay readable.
    final stacked = MediaQuery.textScalerOf(context).scale(16) > 24;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tier.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 2),
        Text(Subscriptions.usageMultiplier(tier),
            style: TextStyle(color: scheme.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 1),
        Text(tier.tagline, style: TextStyle(color: tokens.textMuted, fontSize: 12.5)),
        if (plan.note != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(plan.note!,
                style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );

    final price = Column(
      crossAxisAlignment: stacked ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (plan.wasPrice != null)
          Text(plan.wasPrice!,
              style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 12.5,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: tokens.textMuted)),
        Text.rich(TextSpan(children: [
          TextSpan(
            text: plan.price,
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 20, color: scheme.primary),
          ),
          TextSpan(text: plan.period, style: TextStyle(color: tokens.textMuted, fontSize: 13)),
        ])),
        if (plan.wasPrice != null)
          Text('Launch price',
              style: TextStyle(
                  color: scheme.primary, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
      ],
    );

    return Material(
      color: selected ? tokens.primarySoft : scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : tokens.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? scheme.primary : tokens.textMuted,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [info, const SizedBox(height: 12), price],
                      )
                    : info,
              ),
              if (!stacked) ...[
                const SizedBox(width: 10),
                price,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A feature row whose check/lock reflects the currently selected tier. Rows the
/// selected tier doesn't include show a muted lock plus the tier that unlocks it.
class _FeatureRow extends StatelessWidget {
  final Feature feature;
  final int selectedRank;
  const _FeatureRow({required this.feature, required this.selectedRank});

  static String _tierName(int rank) => switch (rank) {
        1 => 'Lite',
        2 => 'Plus',
        3 => 'Max',
        _ => 'Free',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final included = selectedRank >= feature.minRank;
    final tag = feature.minRank == 0 ? '(free)' : '${_tierName(feature.minRank)}+';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: included ? scheme.primary : t.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(included ? Icons.check_rounded : Icons.lock_outline_rounded,
                size: 15, color: included ? scheme.onPrimary : t.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(child: Text(feature.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5))),
                    const SizedBox(width: 8),
                    Text(tag,
                        style: TextStyle(
                            color: included ? scheme.primary : t.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(feature.desc, style: TextStyle(color: t.textMuted, fontSize: 13.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
