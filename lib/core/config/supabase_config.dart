/// Built-in Supabase configuration for PossessionTracker.
class SupabaseConfig {
  /// Supabase Project URL (cleaned of any sub-paths)
  static const String url = 'https://wwwutnbdnidumlvemizx.supabase.co';

  /// Supabase Anon Public Key (safe to embed on client; RLS enforces access control)
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind3d3V0bmJkbmlkdW1sdmVtaXp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0MTE4MTcsImV4cCI6MjEwNDk4NzgxN30.yF4sAfwdic1iSWUq84ygpOfCfC0AmiFnOSppRbgAJtc';

  /// Whether default credentials are configured
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Helper to sanitize URLs (removes /rest/v1, trailing slashes, etc.)
  static String sanitizeUrl(String rawUrl) {
    var cleaned = rawUrl.trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (cleaned.endsWith('/rest/v1')) {
      cleaned = cleaned.substring(0, cleaned.length - '/rest/v1'.length);
    }
    return cleaned;
  }
}
