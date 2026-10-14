import 'package:http/http.dart' as http;

import '../credentials.dart';
import '../enum/signature_method.dart';
import '../exceptions.dart';
import '../signature.dart';
import 'request_handler.dart';

/// Signs outgoing requests with OAuth 1.0a (HMAC) so they are accepted by
/// NetSuite RESTlets.
///
/// The OAuth `realm` can be provided explicitly via [realm] (recommended —
/// use your account ID, e.g. `TSTDRV1234567`). When [realm] is omitted it is
/// derived automatically from the request host
/// (`https://TSTDRV-1234567.restlets.api.netsuite.com/...` → `TSTDRV_1234567`).
class OAuthHandler extends RequestHandler {
  /// OAuth protocol version sent in the header.
  final String version;

  /// Credentials used for signing every request.
  final Credentials credentials;

  /// HMAC algorithm used to produce `oauth_signature`.
  final SignatureMethod hash;

  /// The OAuth realm (NetSuite account ID, e.g. `TSTDRV1234567`).
  ///
  /// If `null`, the realm is inferred from each request's host name.
  final String? realm;

  OAuthHandler({
    required this.credentials,
    this.realm,
    this.hash = SignatureMethod.HMAC_SHA256,
    this.version = '1.0',
  });

  @override
  http.BaseRequest handle(http.BaseRequest request) {
    try {
      final queryParams = RequestHandler.query(request.url);
      final url = RequestHandler.baseUri(request.url);
      final authHeader = header();
      final baseHeaders = RequestHandler.combine(queryParams, authHeader);

      final queryStr = RequestHandler.queryString(
        RequestHandler.sort(baseHeaders),
      );

      final signatureBaseString = [
        request.method.toUpperCase(),
        RequestHandler.encode(url),
        RequestHandler.encode(queryStr),
      ].join('&');

      final signature = Signature(credentials, method: hash);
      authHeader['oauth_signature'] = signature.hash(signatureBaseString);

      final headerString = build(
        RequestHandler.combine({
          'realm': realm ?? RequestHandler.account(request.url),
        }, authHeader),
      );

      request.headers.addAll({
        'Authorization': headerString,
        'Accept': 'application/json',
      });
      return request;
    } on NetsuiteException {
      rethrow;
    } catch (error) {
      throw OAuthSignatureException('Unable to sign request: $error');
    }
  }

  /// The OAuth parameters (without the signature) added to every request.
  Map<String, String> header() => {
        'oauth_consumer_key': credentials.consumerKey,
        'oauth_nonce': RequestHandler.nonce(),
        'oauth_signature_method': hash.key,
        'oauth_timestamp': RequestHandler.timestamp(),
        'oauth_token': credentials.token,
        'oauth_version': version,
      };

  /// Renders the parameter map into an `OAuth k1="v1", k2="v2"` header value.
  String build(Map<String, String> headers) {
    final parts = headers.entries
        .map((e) => '${e.key}="${RequestHandler.encode(e.value)}"')
        .join(', ');
    return 'OAuth $parts';
  }
}
