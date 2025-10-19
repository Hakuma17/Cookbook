// lib/services/google_oauth.dart
// Centralized Google OAuth configuration to avoid mismatched IDs between screens.

class GoogleOAuthConfig {
  // TODO: Replace with your actual OAuth 2.0 Web client ID from
  // Google Cloud Console > APIs & Services > Credentials.
  // Make sure this is the WEB CLIENT ID (type Web application), not Android.
  static const webClientId =
      '84901598956-f1jcvtke9f9lg84lgso1qpr3hf5rhhkr.apps.googleusercontent.com';

  static const scopes = <String>['email', 'profile', 'openid'];
}
