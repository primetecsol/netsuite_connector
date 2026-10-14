import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:netsuite_connector/netsuite_connector.dart';
import 'package:test/test.dart';

http.Response res(int status, [String body = '']) =>
    http.Response(body, status);

void main() {
  group('NetsuiteResponseException', () {
    test('exposes statusCode and message with body detail', () {
      final e = NetsuiteResponseException(res(404, 'script not found'));
      expect(e.statusCode, 404);
      expect(e.isNotFound, isTrue);
      expect(e.message, contains('404'));
      expect(e.message, contains('script not found'));
    });

    test('parses standard NetSuite error JSON (code/message)', () {
      final body = jsonEncode({
        'code': 'INSUFFICIENT_PERMISSION',
        'message': 'Does not have permission.',
      });
      final e = NetsuiteResponseException(res(401, body));
      expect(e.errorCode, 'INSUFFICIENT_PERMISSION');
      expect(e.errorMessage, 'Does not have permission.');
      expect(e.isPermissionError, isTrue);
      expect(e.jsonBody, isA<Map<String, dynamic>>());
    });

    test('signature expired detection', () {
      final body = jsonEncode({'code': 'OOM_EXPIRED', 'message': 'expired'});
      final e = NetsuiteResponseException(res(401, body));
      expect(e.isSignatureExpired, isTrue);
    });

    test('duplicate nonce detection', () {
      final body = jsonEncode({'code': 'INVALID_NONCE', 'message': 'dup'});
      final e = NetsuiteResponseException(res(401, body));
      expect(e.isDuplicateNonce, isTrue);
    });

    test('rate limited / server error flags', () {
      expect(NetsuiteResponseException(res(429)).isRateLimited, isTrue);
      expect(NetsuiteResponseException(res(500)).isServerError, isTrue);
      expect(NetsuiteResponseException(res(503)).isServerError, isTrue);
      expect(NetsuiteResponseException(res(400)).isServerError, isFalse);
    });

    test('non-JSON body tolerated', () {
      final e = NetsuiteResponseException(res(500, '<html>oops</html>'));
      expect(e.jsonBody, isNull);
      expect(e.errorCode, isNull);
      expect(e.isServerError, isTrue);
    });

    test('toString includes runtime type and message', () {
      final e = NetsuiteResponseException(res(404, 'gone'));
      expect(e.toString(), startsWith('NetsuiteResponseException:'));
    });
  });

  group('Other exceptions', () {
    test('are all NetsuiteException subclasses', () {
      expect(const CredentialsException('x'), isA<NetsuiteException>());
      expect(const InvalidMethodException('x'), isA<NetsuiteException>());
      expect(const NetsuiteFormatException('x'), isA<NetsuiteException>());
      expect(const OAuthSignatureException('x'), isA<NetsuiteException>());
      expect(
        const NetsuiteConnectionException('x', 'cause'),
        isA<NetsuiteException>(),
      );
      expect(
        const NetsuiteTimeoutException('x', timeLimit: Duration(seconds: 1)),
        isA<NetsuiteException>(),
      );
    });

    test('timeout carries timeLimit', () {
      const e = NetsuiteTimeoutException('t', timeLimit: Duration(seconds: 7));
      expect(e.timeLimit, const Duration(seconds: 7));
    });
  });
}
