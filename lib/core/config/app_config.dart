enum AppEnvironment { development, staging, production }

class AppConfig {
  AppConfig._();

  // App Metadata
  static const String appName = 'IPE - POS';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  // Environment mode
  static const AppEnvironment environment = AppEnvironment.development;
  static bool get isDev => environment == AppEnvironment.development;
  static bool get isStaging => environment == AppEnvironment.staging;
  static bool get isProd => environment == AppEnvironment.production;

  // Local Storage / Shared Preferences Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserData = 'user_data';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'app_language';
  static const String keyCashierSession = 'cashier_session';

  // Formatting & Defaults
  static const String defaultLocale = 'id_ID';
  static const String currencySymbol = 'Rp';
  static const int paginationLimit = 15;
}
