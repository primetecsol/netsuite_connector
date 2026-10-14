import 'package:crypto/crypto.dart';

/// OAuth 1.0a signature methods supported by NetSuite.
///
/// NetSuite only accepts `HMAC-SHA1` for RESTlets today; the other variants
/// are kept for compatibility with the 1.x API and custom endpoints.
// ignore: constant_identifier_names
enum SignatureMethod { HMAC_SHA1, HMAC_SHA256, HMAC_SHA384, HMAC_SHA512 }

extension SignatureMethodExt on SignatureMethod {
  static const Map<SignatureMethod, String> keys = {
    SignatureMethod.HMAC_SHA1: 'HMAC-SHA1',
    SignatureMethod.HMAC_SHA256: 'HMAC-SHA256',
    SignatureMethod.HMAC_SHA384: 'HMAC-SHA384',
    SignatureMethod.HMAC_SHA512: 'HMAC-SHA512',
  };

  static const Map<SignatureMethod, Hash> values = {
    SignatureMethod.HMAC_SHA1: sha1,
    SignatureMethod.HMAC_SHA256: sha256,
    SignatureMethod.HMAC_SHA384: sha384,
    SignatureMethod.HMAC_SHA512: sha512,
  };

  String get key => keys[this]!;
  Hash get value => values[this]!;
}
