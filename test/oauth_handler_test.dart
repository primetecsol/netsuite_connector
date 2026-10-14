import 'package:http/http.dart' as http;
import 'package:netsuite_connector/netsuite_connector.dart';
import 'package:test/test.dart';

final credentials = Credentials.fromValues(
  consumerKey: 'consumer-key',
  consumerSecret: 'consumer-secret',
  token: 'token-id',
  tokenSecret: 'token-secret',
);

void main() {
  group('OAuthHandler.handle', () {
    test('adds Authorization header with explicit realm', () {
      final handler =
          OAuthHandler(credentials: credentials, realm: 'TSTDRV123456');
      final request = handler.handle(
        http.Request(
            'GET',
            Uri.parse(
                'https://rest.netsuite.com/app/site/hosting/restlet.nl?script=1&deploy=1')),
      );
      final auth = request.headers['Authorization']!;
      expect(auth, startsWith('OAuth '));
      expect(auth, contains('realm="TSTDRV123456"'));
      expect(auth, contains('oauth_consumer_key="consumer-key"'));
      expect(auth, contains('oauth_token="token-id"'));
      expect(auth, contains('oauth_signature_method="HMAC-SHA256"'));
      expect(auth, contains('oauth_version="1.0"'));
      expect(auth, contains('oauth_signature="'));
      expect(request.headers['Accept'], 'application/json');
    });

    test('defaults to HMAC-SHA256 and accepts other methods', () {
      for (final method in SignatureMethod.values) {
        final handler =
            OAuthHandler(credentials: credentials, realm: 'R', hash: method);
        final signed = handler.handle(
          http.Request('GET', Uri.parse('https://rest.netsuite.com/x')),
        );
        expect(
          signed.headers['Authorization'],
          contains('oauth_signature_method="${method.key}"'),
        );
      }
    });

    test('realm auto-derived from host when not provided', () {
      final handler = OAuthHandler(credentials: credentials);
      final signed = handler.handle(
        http.Request(
            'GET',
            Uri.parse(
                'https://TSTDRV-1234567.restlets.api.netsuite.com/app/site/hosting/restlet.nl')),
      );
      expect(
        signed.headers['Authorization'],
        contains('realm="TSTDRV_1234567"'),
      );
    });

    test('two requests to different URLs produce different signatures', () {
      final handler = OAuthHandler(credentials: credentials, realm: 'R');
      final a = handler
          .handle(http.Request('GET', Uri.parse('https://rest.netsuite.com/a')))
          .headers['Authorization']!;
      final b = handler
          .handle(http.Request('GET', Uri.parse('https://rest.netsuite.com/b')))
          .headers['Authorization']!;
      expect(a, isNot(b));
    });
  });

  group('RequestHandler static helpers', () {
    test('nonce is random, correct length', () {
      final n = RequestHandler.nonce();
      expect(n.length, 32);
      expect(RequestHandler.nonce(), isNot(n));
      expect(RequestHandler.nonce(length: 8).length, 8);
    });

    test('timestamp is current unix seconds', () {
      final ts = int.parse(RequestHandler.timestamp());
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      expect((ts - now).abs(), lessThan(5));
    });

    test('encode percent-encodes reserved chars', () {
      expect(RequestHandler.encode('a b&c=d'), 'a%20b%26c%3Dd');
      expect(RequestHandler.filterQueryString("!*'()"), '%21%2A%27%28%29');
    });

    test('account derives realm from host', () {
      expect(
        RequestHandler.account(
          Uri.parse('https://TSTDRV-1234567.restlets.api.netsuite.com/x'),
        ),
        'TSTDRV_1234567',
      );
    });

    test('sort orders map keys', () {
      final sorted = RequestHandler.sort({'b': '2', 'a': '1', 'c': '3'});
      expect(sorted.keys.toList(), ['a', 'b', 'c']);
    });

    test('combine merges without mutating inputs', () {
      final m1 = {'a': '1'};
      final m2 = {'b': '2'};
      expect(RequestHandler.combine(m1, m2), {'a': '1', 'b': '2'});
      expect(m1.length, 1);
    });

    test('baseUri strips query', () {
      expect(
        RequestHandler.baseUri(Uri.parse('https://x.com/y?a=1')),
        'https://x.com/y',
      );
    });

    test('query parses params', () {
      expect(
        RequestHandler.query(Uri.parse('https://x.com/y?a=1&b=2')),
        {'a': '1', 'b': '2'},
      );
    });
  });
}
