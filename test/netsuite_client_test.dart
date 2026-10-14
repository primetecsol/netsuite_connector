import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:netsuite_connector/netsuite_connector.dart';
import 'package:test/test.dart';

final credentials = Credentials.fromValues(
  consumerKey: 'consumer-key',
  consumerSecret: 'consumer-secret',
  token: 'token-id',
  tokenSecret: 'token-secret',
);

final restletUrl = Uri.parse(
  'https://TSTDRV-1234567.restlets.api.netsuite.com/app/site/hosting/restlet.nl?script=9&deploy=1',
);

NetsuiteClient buildClient(
  Future<http.Response> Function(http.Request) handler, {
  Duration timeLimit = const Duration(seconds: 15),
}) {
  return NetsuiteClient(
    handler: OAuthHandler(credentials: credentials, realm: 'TSTDRV_1234567'),
    timeLimit: timeLimit,
    httpClient: MockClient((request) async => handler(request)),
  );
}

void main() {
  group('Request signing', () {
    test('every request carries an Authorization header', () async {
      late http.Request captured;
      final client = buildClient((req) async {
        captured = req;
        return http.Response('{"ok":true}', 200);
      });

      await client.get(restletUrl);

      expect(captured.headers['Authorization'], startsWith('OAuth '));
      expect(captured.headers['Authorization'],
          contains('realm="TSTDRV_1234567"'));
      expect(captured.headers['Authorization'], contains('oauth_signature="'));
      expect(captured.headers['Accept'], 'application/json');
      client.close();
    });

    test('POST body is sent as JSON with content type', () async {
      late http.Request captured;
      final client = buildClient((req) async {
        captured = req;
        return http.Response('{}', 200);
      });

      await client.postJson(restletUrl, body: {'name': 'John'});

      expect(captured.method, 'POST');
      expect(captured.body, '{"name":"John"}');
      expect(captured.headers['Content-Type'], contains('application/json'));
      client.close();
    });

    test('PUT, PATCH and DELETE verbs are supported', () async {
      final methods = <String>[];
      final client = buildClient((req) async {
        methods.add(req.method);
        return http.Response('', 200);
      });

      await client.put(restletUrl, body: {'a': 1});
      await client.patch(restletUrl, body: {'a': 2});
      await client.delete(restletUrl);
      await client.head(restletUrl);

      expect(methods, ['PUT', 'PATCH', 'DELETE', 'HEAD']);
      client.close();
    });
  });

  group('Error handling', () {
    test('404 -> NetsuiteResponseException.isNotFound', () async {
      final client = buildClient((_) async => http.Response('Not found', 404));
      try {
        await client.get(restletUrl);
        fail('should have thrown');
      } on NetsuiteResponseException catch (e) {
        expect(e.isNotFound, isTrue);
        expect(e.statusCode, 404);
      }
      client.close();
    });

    test('401 permission error helper', () async {
      final client = buildClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'INVALID_LOGIN', 'message': 'perm'}
          }),
          401,
        ),
      );
      try {
        await client.get(restletUrl);
        fail('should have thrown');
      } on NetsuiteResponseException catch (e) {
        expect(e.statusCode, 401);
        expect(e.message, contains('INVALID_LOGIN'));
      }
      client.close();
    });

    test('429 rate limited helper', () async {
      final client = buildClient((_) async => http.Response('slow down', 429));
      try {
        await client.get(restletUrl);
        fail('should have thrown');
      } on NetsuiteResponseException catch (e) {
        expect(e.isRateLimited, isTrue);
      }
      client.close();
    });

    test('5xx server error helper', () async {
      final client = buildClient((_) async => http.Response('boom', 503));
      try {
        await client.get(restletUrl);
        fail('should have thrown');
      } on NetsuiteResponseException catch (e) {
        expect(e.isServerError, isTrue);
      }
      client.close();
    });

    test('timeout -> NetsuiteTimeoutException', () async {
      final client = NetsuiteClient(
        handler: OAuthHandler(credentials: credentials, realm: 'R'),
        timeLimit: const Duration(milliseconds: 50),
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 2));
          return http.Response('late', 200);
        }),
      );
      expect(
        () => client.get(restletUrl),
        throwsA(isA<NetsuiteTimeoutException>()),
      );
      client.close();
    });

    test('invalid JSON response -> NetsuiteFormatException', () async {
      final client = buildClient((_) async => http.Response('<html/>', 200));
      expect(
        () => client.getJson(restletUrl),
        throwsA(isA<NetsuiteFormatException>()),
      );
      client.close();
    });

    test('empty body decode -> NetsuiteFormatException', () {
      expect(
        () => NetsuiteClient.decodeJson(http.Response('', 200)),
        throwsA(isA<NetsuiteFormatException>()),
      );
    });
  });

  group('JSON helpers', () {
    test('getJson decodes a map', () async {
      final client = buildClient(
        (_) async => http.Response(jsonEncode({'id': 42}), 200),
      );
      final data = await client.getJson(restletUrl);
      expect(data['id'], 42);
      client.close();
    });

    test('postJsonAndDecode round-trips', () async {
      final client = buildClient(
        (req) async => http.Response(
          jsonEncode({'echo': jsonDecode(req.body)}),
          200,
        ),
      );
      final data = await client.postJsonAndDecode(restletUrl, body: {'x': 1});
      expect(data['echo'], {'x': 1});
      client.close();
    });
  });
}
