import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'credentials.dart';
import 'enum/signature_method.dart';
import 'exceptions.dart';

/// Computes the OAuth 1.0a `oauth_signature` for a signature base string
/// using HMAC with the credentials' shared secret
/// (`consumer_secret & token_secret`).
class Signature {
  final Credentials credentials;
  final SignatureMethod method;

  const Signature(this.credentials, {this.method = SignatureMethod.HMAC_SHA256});

  /// The signing key: `consumerSecret & tokenSecret` (OAuth 1.0a form used
  /// by NetSuite).
  String get signingKey =>
      '${credentials.consumerSecret}&${credentials.tokenSecret}';

  /// Returns the base64 encoded HMAC digest of [message].
  ///
  /// Throws an [OAuthSignatureException] if hashing fails for any reason.
  String hash(String message) {
    try {
      final bytes = utf8.encode(message);
      final secret = utf8.encode(signingKey);
      final digest = Hmac(method.value, secret).convert(bytes);
      return base64Encode(digest.bytes);
    } catch (error) {
      throw OAuthSignatureException(
        'Failed to compute OAuth signature with ${method.key}: $error',
      );
    }
  }
}
