import 'exceptions.dart';

/// Immutable, strongly typed set of OAuth 1.0a credentials required to talk
/// to a NetSuite RESTlet.
///
/// All four values are mandatory; constructing this object with missing or
/// blank values throws a [CredentialsException] immediately (fail fast),
/// instead of failing later with an opaque HTTP 401.
class Credentials {
  /// Legacy key names accepted by the map based constructor.
  static const String consumerKeyField = 'consumer_key';
  static const String consumerSecretField = 'consumer_secret';
  static const String tokenField = 'token';
  static const String tokenSecretField = 'token_secret';

  final String _consumerKey;
  final String _consumerSecret;
  final String _token;
  final String _tokenSecret;

  /// Creates credentials from explicit, null-safe named parameters.
  ///
  /// ```dart
  /// final credentials = Credentials.fromValues(
  ///   consumerKey: '...',
  ///   consumerSecret: '...',
  ///   token: '...',
  ///   tokenSecret: '...',
  /// );
  /// ```
  factory Credentials.fromValues({
    required String consumerKey,
    required String consumerSecret,
    required String token,
    required String tokenSecret,
  }) {
    return Credentials._(
      _validated(consumerKeyField, consumerKey),
      _validated(consumerSecretField, consumerSecret),
      _validated(tokenField, token),
      _validated(tokenSecretField, tokenSecret),
    );
  }

  /// Creates credentials from a `Map<String, dynamic>` (backwards compatible
  /// with the 1.x API).
  ///
  /// Required keys: `consumer_key`, `consumer_secret`, `token`,
  /// `token_secret`. Every value must be a non-empty [String].
  factory Credentials(Map<String, dynamic> credentials) {
    if (credentials.isEmpty) {
      throw const CredentialsException('Credentials should not be empty.');
    }

    for (final key in const [
      consumerKeyField,
      consumerSecretField,
      tokenField,
      tokenSecretField,
    ]) {
      if (!credentials.containsKey(key)) {
        throw CredentialsException('Credentials must include $key.');
      }
    }

    try {
      return Credentials.fromValues(
        consumerKey: credentials[consumerKeyField] as String,
        consumerSecret: credentials[consumerSecretField] as String,
        token: credentials[tokenField] as String,
        tokenSecret: credentials[tokenSecretField] as String,
      );
    } on TypeError {
      throw const CredentialsException(
        'All credential values must be non-empty Strings.',
      );
    }
  }

  const Credentials._(
    this._consumerKey,
    this._consumerSecret,
    this._token,
    this._tokenSecret,
  );

  static String _validated(String name, String value) {
    if (value.trim().isEmpty) {
      throw CredentialsException(
        'Credentials field "$name" must not be empty.',
      );
    }
    return value;
  }

  /// The OAuth consumer key (Token ID of the TBA integration).
  String get consumerKey => _consumerKey;

  /// The OAuth consumer secret (Token Secret of the TBA integration).
  String get consumerSecret => _consumerSecret;

  /// The OAuth access token (Key ID).
  String get token => _token;

  /// The OAuth access token secret.
  String get tokenSecret => _tokenSecret;

  /// Backwards compatible alias of [token] used by the 1.x releases.
  String get tokenKey => _token;

  /// A safe representation that never leaks secrets into logs.
  @override
  String toString() =>
      'Credentials(consumerKey: ${_mask(_consumerKey)}, token: ${_mask(_token)})';

  static String _mask(String value) {
    if (value.length <= 4) return '****';
    return '${value.substring(0, 4)}…';
  }
}
