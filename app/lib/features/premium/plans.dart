/// Subscription catalogue — the single source of truth for tiers, product IDs,
/// prices, daily caps, and the per-feature gating. The store-side products
/// (Google Play / App Store Connect) and the RevenueCat dashboard MUST use these
/// exact product `id`s and `entitlement` names.
///
/// Tiers are STACKED. RevenueCat entitlements are additive: Lite grants `lite`,
/// Plus grants `lite`+`plus`, Max grants `lite`+`plus`+`max`. The active tier is
/// the highest entitlement held; features unlock at a minimum tier rank.
library;

enum Billing { monthly, annual }

class Plan {
  final String id; // store / RevenueCat product identifier
  final Billing billing;
  final String price; // current (launch) display price, e.g. 'S$9.90'
  final String period; // '/month' | '/year'
  final String? note; // savings badge, shown when set
  /// Regular price shown struck-through (the genuine post-launch price). Only
  /// set this to a price you actually intend to charge later — it's a real
  /// launch discount, not a fictitious one.
  final String? wasPrice;
  const Plan({
    required this.id,
    required this.billing,
    required this.price,
    required this.period,
    this.note,
    this.wasPrice,
  });
}

class Tier {
  final String key; // 'lite' | 'plus' | 'max' — matches RC entitlement + subscriptions.tier
  final int rank; // 1 | 2 | 3 (free = 0)
  final String name; // user-facing, e.g. 'Lactic Plus'
  final String tagline; // one-line value prop
  final int dailyCap; // questions/day (the "Lactic Acid" allowance)
  final Plan monthly;
  final Plan annual;
  const Tier({
    required this.key,
    required this.rank,
    required this.name,
    required this.tagline,
    required this.dailyCap,
    required this.monthly,
    required this.annual,
  });

  Plan plan(Billing b) => b == Billing.annual ? annual : monthly;
}

/// A paywall feature row and the minimum tier rank that unlocks it.
class Feature {
  final String title;
  final String desc;
  final int minRank; // 0 free, 1 Lite, 2 Plus, 3 Max
  const Feature(this.title, this.desc, this.minRank);
}

class Subscriptions {
  // Stacked RevenueCat entitlement identifiers. Configure each store product to
  // grant its own entitlement AND all lower ones.
  static const eLite = 'lite';
  static const ePlus = 'plus';
  static const eMax = 'max';

  // Free tier daily cap (no subscription, signed in). Enforced server-side too.
  static const freeDailyCap = 30;

  static const lite = Tier(
    key: 'lite',
    rank: 1,
    name: 'Lactic Lite',
    tagline: 'More questions a day, same friendly tutor.',
    dailyCap: 50, // free DeepSeek model, just a higher daily limit (~$3/mo)
    monthly: Plan(id: 'lactic_lite_monthly', billing: Billing.monthly, price: 'S\$7.90', period: '/month', wasPrice: 'S\$9.90'),
    annual: Plan(
      id: 'lactic_lite_annual', billing: Billing.annual,
      price: 'S\$79', period: '/year', note: 'Save 17% · 2 months free', wasPrice: 'S\$99',
    ),
  );

  static const plus = Tier(
    key: 'plus',
    rank: 2,
    name: 'Lactic Plus',
    tagline: 'Smarter model, photo solve, and Marks Coach.',
    dailyCap: 75,
    monthly: Plan(id: 'lactic_plus_monthly', billing: Billing.monthly, price: 'S\$13.90', period: '/month', wasPrice: 'S\$16.90'),
    annual: Plan(
      id: 'lactic_plus_annual', billing: Billing.annual,
      price: 'S\$139', period: '/year', note: 'Save 17% · 2 months free', wasPrice: 'S\$169',
    ),
  );

  static const max = Tier(
    key: 'max',
    rank: 3,
    name: 'Lactic Max',
    tagline: 'The full coaching machine, with the most usage.',
    dailyCap: 115,
    monthly: Plan(id: 'lactic_max_monthly', billing: Billing.monthly, price: 'S\$19.90', period: '/month', wasPrice: 'S\$23.90'),
    annual: Plan(
      id: 'lactic_max_annual', billing: Billing.annual,
      price: 'S\$199', period: '/year', note: 'Save 17% · 2 months free', wasPrice: 'S\$239',
    ),
  );

  static const tiers = [lite, plus, max];

  /// Rank a feature needs. Used by the app to gate, and by the paywall list.
  /// Lite (rank 1) is ONLY a higher daily limit — same free model, no photo.
  /// The smarter model + photo start at Plus (rank 2).
  static const rankMoreUsage = 1; // Lite+ (just a bigger daily allowance)
  static const rankSmarterModel = 2; // Plus+ (Gemini; Lite stays on the free model)
  static const rankPhoto = 2; // Plus+
  static const rankMarksCoach = 2; // Plus+
  static const rankMastery = 2; // Plus+
  static const rankDrilling = 3; // Max

  /// Paywall feature list (ordered). minRank drives the per-tier checkmarks.
  static const features = <Feature>[
    Feature('Tutor answers', 'Chat-based help on your study questions.', 0),
    Feature('More daily questions', 'A higher daily limit so you can keep studying.', rankMoreUsage),
    Feature('Smarter model', 'Faster, sharper answers from a more capable model.', rankSmarterModel),
    Feature('Photo upload', 'Snap a printed question or your own working.', rankPhoto),
    Feature('Marks Coach', 'Examiner-style feedback on your written answers.', rankMarksCoach),
    Feature('Mastery tracking', 'See your progress across every syllabus topic.', rankMastery),
    Feature('Weak-spot drilling', 'Targeted practice on what you keep getting wrong.', rankDrilling),
  ];

  /// Highest tier rank for a set of active entitlement keys (0 = free).
  static int rankOf(Set<String> entitlements) {
    if (entitlements.contains(eMax)) return 3;
    if (entitlements.contains(ePlus)) return 2;
    if (entitlements.contains(eLite)) return 1;
    return 0;
  }
}
