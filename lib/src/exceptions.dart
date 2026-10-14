import 'dart:convert';

import 'package:http/http.dart' as http;

/// Base class for every error thrown by `netsuite_connector`.
///
/// Catch this single type to handle all package-specific failures:
///
/// ```dart
/// try {
///   final response = await client.get(url);
/// } on NetsuiteException catch (e) {
///   print(e.message);
/// }
/// ```
abstract class NetsuiteException implements Exception {
  /// Human readable, developer friendly description of the error.
  final String message;

  const NetsuiteException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when [Credentials] are empty, missing required OAuth keys, or
/// contain values that are not non-empty strings.
class CredentialsException extends NetsuiteException {
  const CredentialsException(super.message);
}

/// Thrown when an unsupported / invalid HTTP method is requested.
class InvalidMethodException extends NetsuiteException {
  const InvalidMethodException(super.message);
}

/// Thrown when a response body cannot be decoded as the expected JSON shape.
class NetsuiteFormatException extends NetsuiteException {
  const NetsuiteFormatException(super.message);
}

/// Thrown when a request cannot be signed or prepared (OAuth layer failure).
class OAuthSignatureException extends NetsuiteException {
  const OAuthSignatureException(super.message);
}

/// Thrown when the underlying transport fails (DNS failure, socket error,
/// connection refused, timeout while connecting, ...).
///
/// The original error is preserved in [cause].
class NetsuiteConnectionException extends NetsuiteException {
  /// The original error thrown by the HTTP client / OS.
  final Object cause;

  const NetsuiteConnectionException(super.message, this.cause);
}

/// Thrown when the server did not respond within the configured `timeLimit`.
class NetsuiteTimeoutException extends NetsuiteException {
  /// How long the client waited before giving up.
  final Duration timeLimit;

  const NetsuiteTimeoutException(
    super.message, {
    required this.timeLimit,
  });
}

/// Thrown when NetSuite answers with a non-success (status >= 400) response.
///
/// This is the most common error you will handle in application code. It
/// exposes the parsed NetSuite error body (when available) so you can react
/// to specific failure codes without string matching.
class NetsuiteResponseException extends NetsuiteException {
  /// The full HTTP response returned by NetSuite.
  final http.Response response;

  /// HTTP status code (shortcut for `response.statusCode`).
  int get statusCode => response.statusCode;

  /// Response body decoded as JSON when possible, otherwise `null`.
  Map<String, dynamic>? get jsonBody => _tryJson(response.body);

  /// NetSuite's error `code` when the body follows the standard RESTlet
  /// error format, e.g. `SSO: INVALID_RESPONSE`, `INVALID_LOGIN`, ...
  String? get errorCode => jsonBody?['code'] as String?;

  /// NetSuite's human readable error message from the standard error format.
  String? get errorMessage => jsonBody?['message'] as String?;

  /// True when NetSuite reports a TBA permissions failure.
  bool get isPermissionError =>
      statusCode == 401 || (errorCode?.contains('INSUFFICIENT') ?? false);

  /// True when NetSuite reports an expired/invalid OAuth signature, usually
  /// caused by clock skew between this machine and NetSuite.
  bool get isSignatureExpired =>
      statusCode == 401 &&
      (errorCode?.toUpperCase().contains('EXPIRED') ?? false);

  /// True when the request was rejected because of a duplicate nonce
  /// (replay protection). Simply retrying the request fixes it.
  bool get isDuplicateNonce =>
      statusCode == 401 &&
      (errorCode?.toUpperCase().contains('NONCE') ?? false);

  /// True when NetSuite rate-limited the request (HTTP 429).
  bool get isRateLimited => statusCode == 429;

  /// True for server side failures (HTTP 5xx) — safe to retry with back-off.
  bool get isServerError => statusCode >= 500 && statusCode <= 599;

  /// True when the requested script/deploy could not be found (HTTP 404).
  bool get isNotFound => statusCode == 404;

  NetsuiteResponseException(
    this.response, {
    String? message,
  }) : super(message ?? _defaultMessage(response));

  static String _defaultMessage(http.Response response) {
    final json = _tryJson(response.body);
    final detail = json != null
        ? (json['message'] ?? json['error'] ?? response.body).toString()
        : response.body;
    return 'NetSuite responded with status ${response.statusCode}'
        '${detail.isEmpty ? '' : ': $detail'}';
  }

  static Map<String, dynamic>? _tryJson(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
