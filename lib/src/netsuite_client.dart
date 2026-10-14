import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'handlers/request_handler.dart';

/// A ready-to-use HTTP client that authenticates every request through a
/// [RequestHandler] (normally an `OAuthHandler`) and exposes convenient,
/// null-safe helpers for all REST verbs: GET, POST, PUT/PATCH (update),
/// DELETE, HEAD.
///
/// ```dart
/// final client = NetsuiteClient(
///   handler: OAuthHandler(credentials: credentials),
///   timeLimit: Duration(seconds: 30),
/// );
///
/// final response = await client.get(url);          // raw http.Response
/// final data     = await client.getJson(url);      // decoded JSON
/// await client.postJson(url, body: payload);       // send JSON body
/// ```
///
/// Every failure surfaces as a typed [NetsuiteException] subclass — see
/// `lib/src/exceptions.dart` — so application code can react precisely
/// (retry on timeouts, re-auth on 401, etc.) without string matching.
class NetsuiteClient extends http.BaseClient {
  /// Signs / prepares every outgoing request.
  final RequestHandler handler;

  /// Maximum time to wait for a complete response before throwing a
  /// [NetsuiteTimeoutException].
  final Duration timeLimit;

  /// Optional underlying transport. Inject a custom [http.Client] in tests or
  /// when you need proxies / retries at the transport level.
  final http.Client _inner;

  NetsuiteClient({
    required this.handler,
    this.timeLimit = const Duration(seconds: 15),
    http.Client? httpClient,
  }) : _inner = httpClient ?? http.Client();

  // --------------------------------------------------------------------------
  // Core send
  // --------------------------------------------------------------------------

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final signed = handler.handle(request);
    return _inner.send(signed).timeout(timeLimit);
  }

  // --------------------------------------------------------------------------
  // Verb helpers (GET / POST / PUT / PATCH / DELETE / HEAD)
  // --------------------------------------------------------------------------

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _sendRequest('GET', url, headers: headers);

  @override
  Future<http.Response> post(
    Uri url, {
    Object? body,
    Map<String, String>? headers,
    Encoding? encoding,
  }) =>
      _sendRequest(
        'POST',
        url,
        body: _encodeBody(body),
        headers: headers,
        encoding: encoding,
        defaultContentType: 'application/json',
      );

  /// Create a JSON payload in one call.
  Future<http.Response> postJson(
    Uri url, {
    required Object body,
    Map<String, String>? headers,
  }) =>
      _sendRequest(
        'POST',
        url,
        body: jsonEncode(body),
        headers: headers,
        defaultContentType: 'application/json',
      );

  /// Update a record (HTTP PUT). Many RESTlets use PUT for updates; if yours
  /// expects PATCH, use [patch] instead — they behave identically here.
  @override
  Future<http.Response> put(
    Uri url, {
    Object? body,
    Map<String, String>? headers,
    Encoding? encoding,
  }) =>
      _sendRequest(
        'PUT',
        url,
        body: _encodeBody(body),
        headers: headers,
        encoding: encoding,
        defaultContentType: 'application/json',
      );

  /// Partial update (HTTP PATCH).
  @override
  Future<http.Response> patch(
    Uri url, {
    Object? body,
    Map<String, String>? headers,
    Encoding? encoding,
  }) =>
      _sendRequest(
        'PATCH',
        url,
        body: _encodeBody(body),
        headers: headers,
        encoding: encoding,
        defaultContentType: 'application/json',
      );

  @override
  Future<http.Response> delete(
    Uri url, {
    Object? body,
    Map<String, String>? headers,
    Encoding? encoding,
  }) =>
      _sendRequest(
        'DELETE',
        url,
        body: _encodeBody(body),
        headers: headers,
        encoding: encoding,
      );

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) =>
      _sendRequest('HEAD', url, headers: headers);

  // --------------------------------------------------------------------------
  // JSON convenience helpers
  // --------------------------------------------------------------------------

  /// GET the [url] and decode the JSON object response.
  ///
  /// Throws [NetsuiteResponseException] on HTTP errors and
  /// [NetsuiteFormatException] when the body is not a JSON object.
  Future<Map<String, dynamic>> getJson(
    Uri url, {
    Map<String, String>? headers,
  }) =>
      _readJson(() => get(url, headers: headers));

  /// POST [body] (encoded as JSON) and decode the JSON object response.
  Future<Map<String, dynamic>> postJsonAndDecode(
    Uri url, {
    required Object body,
    Map<String, String>? headers,
  }) =>
      _readJson(() => postJson(url, body: body, headers: headers));

  /// PUT [body] (encoded as JSON) and decode the JSON object response.
  Future<Map<String, dynamic>> putJsonAndDecode(
    Uri url, {
    required Object body,
    Map<String, String>? headers,
  }) =>
      _readJson(() => put(url, body: body, headers: headers));

  /// Decode the response of any future [http.Response] into a JSON map.
  static Map<String, dynamic> decodeJson(http.Response response) {
    if (response.body.isEmpty) {
      throw const NetsuiteFormatException('Response body is empty.');
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw NetsuiteFormatException(
        'Expected a JSON object but got ${decoded.runtimeType}.',
      );
    } on FormatException catch (error) {
      throw NetsuiteFormatException(
        'Response body is not valid JSON: ${error.message}',
      );
    }
  }

  Future<Map<String, dynamic>> _readJson(
    Future<http.Response> Function() action,
  ) async =>
      decodeJson(await action());

  // --------------------------------------------------------------------------
  // Internals
  // --------------------------------------------------------------------------

  String? _encodeBody(Object? body) {
    if (body == null) return null;
    if (body is String) return body;
    if (body is List<int>) return null; // handled below via bytes
    return jsonEncode(body);
  }

  Future<http.Response> _sendRequest(
    String method,
    Uri url, {
    String? body,
    Map<String, String>? headers,
    Encoding? encoding,
    String? defaultContentType,
  }) async {
    late final http.Request request;

    switch (method.toUpperCase()) {
      case 'GET':
        request = http.Request('GET', url);
        break;
      case 'HEAD':
        request = http.Request('HEAD', url);
        break;
      case 'DELETE':
        request = http.Request('DELETE', url);
        break;
      case 'POST':
      case 'PUT':
      case 'PATCH':
        request = http.Request(method.toUpperCase(), url);
        if (body != null) {
          request.body = body;
          request.headers['Content-Type'] =
              defaultContentType ?? 'application/json';
        }
        break;
      default:
        throw InvalidMethodException(
          'Unsupported HTTP method "$method". Use GET, POST, PUT, PATCH, '
          'DELETE or HEAD.',
        );
    }

    if (encoding != null) request.encoding = encoding;
    if (headers != null) request.headers.addAll(headers);

    try {
      final streamed = await send(request);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 400) {
        throw NetsuiteResponseException(response);
      }
      return response;
    } on TimeoutException {
      throw NetsuiteTimeoutException(
        'Request to $url timed out after ${timeLimit.inSeconds}s.',
        timeLimit: timeLimit,
      );
    } on SocketException catch (error) {
      throw NetsuiteConnectionException(
        'Could not reach NetSuite at $url: ${error.osError ?? error.message}',
        error,
      );
    } on NetsuiteException {
      rethrow;
    } catch (error) {
      throw NetsuiteConnectionException(
        'Could not reach NetSuite at $url: $error',
        error,
      );
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
