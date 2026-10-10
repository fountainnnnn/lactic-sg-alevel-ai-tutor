/// Backend configuration, supplied at build time so the app is not tied to any
/// one Supabase project:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
///     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
///     --dart-define=REVENUECAT_TEST_KEY=test_...
///
/// These are client-side values (the publishable key is not a secret), so what
/// a client can read is decided by your database's RLS policies, not by
/// keeping these hidden.
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static String get chatEndpoint => '$supabaseUrl/functions/v1/chat';
  static String get usageEndpoint => '$supabaseUrl/functions/v1/usage';
  static String get deleteAccountEndpoint =>
      '$supabaseUrl/functions/v1/delete-account';

  /// RevenueCat public SDK keys. A `test_` key targets RevenueCat's Test Store,
  /// so purchases can be exercised without App Store / Play Store setup. For
  /// production, supply the platform keys (Apple `appl_…`, Google `goog_…`).
  static const _revenueCatTestKey = String.fromEnvironment('REVENUECAT_TEST_KEY');
  static const _revenueCatAppleKey = String.fromEnvironment('REVENUECAT_APPLE_KEY');
  static const _revenueCatGoogleKey = String.fromEnvironment('REVENUECAT_GOOGLE_KEY');

  /// Resolves the right key per platform, falling back to the test key while the
  /// production keys are empty. [isApple] should be Platform.isIOS||isMacOS.
  static String revenueCatKey({required bool isApple}) {
    final prod = isApple ? _revenueCatAppleKey : _revenueCatGoogleKey;
    return prod.isNotEmpty ? prod : _revenueCatTestKey;
  }
}
