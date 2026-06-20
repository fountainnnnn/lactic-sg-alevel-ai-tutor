/// Backend configuration. These are the public, client-safe Supabase values
/// (publishable key — NOT a secret). The chat Edge Function accepts this key for
/// anonymous use (ALLOW_ANON) or the signed-in user's JWT.
class Config {
  static const supabaseUrl = 'https://your-project-ref.supabase.co';
  static const supabasePublishableKey =
      'sb_publishable_REDACTED';

  static String get chatEndpoint => '$supabaseUrl/functions/v1/chat';
  static String get usageEndpoint => '$supabaseUrl/functions/v1/usage';
  static String get deleteAccountEndpoint =>
      '$supabaseUrl/functions/v1/delete-account';

  /// RevenueCat public SDK key. Public/client-safe (like the publishable key
  /// above). The `test_` key targets RevenueCat's Test Store, so purchases can
  /// be exercised WITHOUT App Store / Play Store setup. For production, swap in
  /// the platform keys (Apple `appl_…`, Google `goog_…`) — see [revenueCatKey].
  static const _revenueCatTestKey = 'test_REDACTED';
  static const _revenueCatAppleKey = ''; // appl_… (fill for iOS production)
  static const _revenueCatGoogleKey = ''; // goog_… (fill for Android production)

  /// Resolves the right key per platform, falling back to the test key while the
  /// production keys are empty. [isApple] should be Platform.isIOS||isMacOS.
  static String revenueCatKey({required bool isApple}) {
    final prod = isApple ? _revenueCatAppleKey : _revenueCatGoogleKey;
    return prod.isNotEmpty ? prod : _revenueCatTestKey;
  }
}
