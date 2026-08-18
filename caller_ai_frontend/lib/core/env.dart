// ============================================================
// Caller AI - Environment Configuration
// Non-secret keys only. Secret keys stay on backend.
// ============================================================

class AppEnv {
  // Supabase (public keys only)
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

  // Backend API
  static const String apiBaseUrl = 'https://api.callerai.app/api/v1';

  // Google AdMob
  static const String admobAppId = 'ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx';
  static const String admobBannerAdUnit = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';

  // Firebase (initialized from google-services.json / GoogleService-Info.plist)
  // No manual key needed here.

  // Mixpanel
  static const String mixpanelToken = 'your_mixpanel_project_token';

  // App
  static const String appVersion = '2.0.0';
  static const bool isDebug = true;
}
