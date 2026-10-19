// ============================================================
// Caller AI - Environment Configuration
// Build-time configuration via --dart-define. No hardcoded secrets.
// ============================================================

class AppEnv {
  // Supabase (public keys only, injected via --dart-define)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Backend API
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.callerai.app/api/v1',
  );

  // Google AdMob
  static const String admobAppId = String.fromEnvironment(
    'ADMOB_APP_ID',
    defaultValue: '',
  );
  static const String admobBannerAdUnit = String.fromEnvironment(
    'ADMOB_BANNER_AD_UNIT',
    defaultValue: '',
  );

  // Mixpanel
  static const String mixpanelToken = String.fromEnvironment(
    'MIXPANEL_TOKEN',
    defaultValue: '',
  );

  // App
  static const String appVersion = '1.0.0';
  static const bool isDebug = bool.fromEnvironment('DEBUG', defaultValue: false);
}
