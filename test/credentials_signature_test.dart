import 'package:netsuite_connector/netsuite_connector.dart';
import 'package:test/test.dart';

void main() {
  group('Credentials', () {
    test('fromValues stores all values', () {
      final c = Credentials.fromValues(
        consumerKey: 'ck',
        consumerSecret: 'cs',
        token: 'tk',
        tokenSecret: 'ts',
      );
      expect(c.consumerKey, 'ck');
      expect(c.consumerSecret, 'cs');
      expect(c.token, 'tk');
      expect(c.tokenKey, 'tk'); // 1.x alias
      expect(c.tokenSecret, 'ts');
    });

    test('throws CredentialsException on blank value', () {
      expect(
        () => Credentials.fromValues(
          consumerKey: '   ',
          consumerSecret: 'cs',
          token: 'tk',
          tokenSecret: 'ts',
        ),
        throwsA(isA<CredentialsException>()),
      );
    });

    test('legacy map constructor uses snake_case keys', () {
      final c = Credentials({
        'consumer_key': 'ck',
        'consumer_secret': 'cs',
        'token': 'tk',
        'token_secret': 'ts',
      });
      expect(c.consumerKey, 'ck');
      expect(c.tokenSecret, 'ts');
    });

    test('legacy map constructor rejects missing keys', () {
      expect(
        () => Credentials({'consumer_key': 'ck'}),
        throwsA(isA<CredentialsException>()),
      );
    });

    test('toString masks secrets', () {
      final c = Credentials.fromValues(
        consumerKey: 'super-secret-key',
        consumerSecret: 'super-secret-value',
        token: 'super-secret-token',
        tokenSecret: 'super-secret-tsecret',
      );
      final s = c.toString();
      expect(s, isNot(contains('super-secret-value')));
      expect(s, isNot(contains('super-secret-tsecret')));
    });
  });

  group('Signature', () {
    test('HMAC output is deterministic base64', () {
      final c = Credentials.fromValues(
        consumerKey: 'ck',
        consumerSecret: 'cs',
        token: 'tk',
        tokenSecret: 'ts',
      );
      for (final method in SignatureMethod.values) {
        final sig = Signature(c, method: method);
        final a = sig.hash('GET&https%3A%2F%2Fx&base');
        final b = sig.hash('GET&https%3A%2F%2Fx&base');
        expect(a, b);
        expect(a, isNotEmpty);
      }
    });

    test('signing key is consumerSecret&tokenSecret', () {
      final c = Credentials.fromValues(
        consumerKey: 'ck',
        consumerSecret: 'cs',
        token: 'tk',
        tokenSecret: 'ts',
      );
      expect(Signature(c).signingKey, 'cs&ts');
    });
  });
}
