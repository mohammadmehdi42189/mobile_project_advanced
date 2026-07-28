class AppConfig {
  static const omdbApiKey = String.fromEnvironment('OMDB_API_KEY');
  static const omdbBaseUrl = 'https://www.omdbapi.com/';
  static const advancedMode = bool.fromEnvironment('ADVANCED_MODE');
  static const backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://localhost:3000/api/v1',
  );
  static const backendCertificateSha256 = String.fromEnvironment(
    'BACKEND_CERT_SHA256',
  );
}
