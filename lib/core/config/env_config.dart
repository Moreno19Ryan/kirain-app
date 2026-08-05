/// Supabase connection config, selected at build time via --dart-define.
///
/// Defaults to the kirain-dev project so local runs work out of the box.
/// Override for production builds with:
///   flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class EnvConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qxjwjfcxbikbugwvexob.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_1GRO2YzfenTfXOz_1MMyjw_I1rIfWVW',
  );
}
