/// Backend configuration. These are the public, client-safe Supabase values
/// (publishable key — NOT a secret). The chat Edge Function accepts this key for
/// anonymous use (ALLOW_ANON) or the signed-in user's JWT.
class Config {
  static const supabaseUrl = 'https://your-project-ref.supabase.co';
  static const supabasePublishableKey =
      'sb_publishable_REDACTED';

  static String get chatEndpoint => '$supabaseUrl/functions/v1/chat';
}
