import 'dart:math';

import 'package:http/http.dart' as http;

/// Contract for anything that can prepare an outgoing [http.BaseRequest]
/// (typically by adding authentication headers) before it is sent.
abstract class RequestHandler {
  /// Returns the [request] with all required auth headers applied.
  ///
  /// Implementations may mutate and return the same object, or wrap it in a
  /// new one. Must throw a [NetsuiteException] subclass on failure — never
  /// return `null`.
  http.BaseRequest handle(http.BaseRequest request);

  // --------------------------------------------------------------------------
  // Shared OAuth helpers (previously instance methods on the abstract class).
  // They are now `static` so they can be used without instantiating a handler
  // and carry explicit null-safe types.
  // --------------------------------------------------------------------------

  /// Parses the query string of [uri] into a flat map.
  static Map<String, String> query(Uri uri) => Uri.splitQueryString(uri.query);

  /// The URI without query parameters — the base used for signing.
  static String baseUri(Uri uri) =>
      Uri(scheme: uri.scheme, host: uri.host, path: uri.path).toString();

  /// Cryptographically-strong random OAuth nonce of the given [length].
  static String nonce({int length = 32}) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[rnd.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  /// Current UTC unix timestamp in seconds, as required by OAuth 1.0a.
  static String timestamp() =>
      (DateTime.now().toUtc().millisecondsSinceEpoch / 1000).round().toString();

  /// RFC 3986 percent-encoding used by OAuth.
  static String encode(String str) => Uri.encodeComponent(str);

  /// Derives the NetSuite account realm (e.g. `TSTDRV1234567`) from the
  /// restlet host name.
  static String account(Uri uri) =>
      uri.host.split('.').first.replaceAll('-', '_').toUpperCase();

  /// Returns a copy of [map] sorted by key (required for the signature base
  /// string parameter normalization).
  static Map<String, String> sort(Map<String, String> map) => Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));

  /// Merges [second] into a copy of [first] (does not mutate the inputs).
  static Map<String, String> combine(
    Map<String, String> first,
    Map<String, String> second,
  ) =>
      {...first, ...second};

  /// Normalizes parameters into an OAuth `application/x-www-form-urlencoded`
  /// style string, handling nested maps/lists like the 1.x behaviour.
  static String queryString(
    Map<Object?, Object?> params, {
    String prefix = '&',
    bool inRecursion = false,
  }) {
    final query = StringBuffer();

    params.forEach((key, value) {
      var k = key;
      if (inRecursion) k = '[$k]';

      if (value is String || value is num || value is bool) {
        query.write('$prefix$k=$value');
      } else if (value is List) {
        value.asMap().forEach((index, element) {
          query.write(queryString(
            {index: element},
            prefix: '$prefix$k',
            inRecursion: true,
          ));
        });
      } else if (value is Map) {
        value.forEach((nestedKey, nestedValue) {
          query.write(queryString(
            {nestedKey: nestedValue},
            prefix: '$prefix$k',
            inRecursion: true,
          ));
        });
      }
    });

    final result = query.toString();
    if (result.isEmpty) return '';
    return filterQueryString(result.substring(prefix.length));
  }

  /// Escapes characters that `Uri.encodeComponent` leaves untouched but
  /// OAuth requires to be percent-encoded.
  static String filterQueryString(String string) => string
      .replaceAll('!', '%21')
      .replaceAll('*', '%2A')
      .replaceAll("'", '%27')
      .replaceAll('(', '%28')
      .replaceAll(')', '%29');
}
