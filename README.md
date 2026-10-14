# netsuite_connector

A **production-ready, null-safe** Dart client for [NetSuite](https://www.netsuite.com/) RESTlets using **OAuth 1.0a** (HMAC) request signing.

[![pub package](https://img.shields.io/badge/pub-v2.0.0-blue)](https://pub.dev/packages/netsuite_connector)
[![Dart](https://img.shields.io/badge/Dart-3.0%2B-nullsafe?style=flat&logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/license-Apache--2.0-green)](./LICENSE)

---

## ✨ Features

- ✅ **Full null safety** — rewritten from the ground up for Dart 3 / sound null safety
- ✅ **All REST verbs** — `GET`, `POST`, `PUT` (update), `PATCH`, `DELETE`, `HEAD`
- ✅ **OAuth 1.0a signing** — HMAC-SHA1 / SHA256 / SHA384 / SHA512
- ✅ **Realm support** — set your NetSuite account ID explicitly (`realm:`) or let it be derived from the request host automatically
- ✅ **Typed error handling** — every failure is a `NetsuiteException` subclass with helpers like `isPermissionError`, `isRateLimited`, `isSignatureExpired` — no more string matching
- ✅ **JSON helpers** — send and decode JSON in one call (`getJson`, `postJsonAndDecode`, `putJsonAndDecode`)
- ✅ **Timeouts & transport control** — configurable `timeLimit`, injectable `http.Client` for proxies/testing
- ✅ **Fail-fast credentials** — invalid or missing keys throw immediately at construction time
- ✅ **Secure nonces** — cryptographically strong `Random.secure()` nonce generation

---

## 📦 Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  netsuite_connector: ^2.0.0
```

Then run:

```bash
dart pub get
```

Or from the command line:

```bash
dart pub add netsuite_connector
```

**Requirements:** Dart SDK `>=3.0.0 <4.0.0`. Works on the Dart VM (server / CLI); any platform supported by `package:http`.

---

## 🔑 Prerequisites — NetSuite Credentials

This package talks to **RESTlets**, so you need a Token-Based Authentication (TBA) setup in NetSuite:

1. Enable **Token-Based Authentication** and **Restlet Web Services** in your account.
2. Create an **Integration Record** → note the **Consumer Key** and **Consumer Secret**.
3. Create an **Access Token** for a role that has permission to your script → note the **Token ID** and **Token Secret**.
4. Deploy your RESTlet script → note the **Script ID** and **Deployment ID**.
5. Your RESTlet URL looks like:

   ```
   https://<ACCOUNT-ID>.restlets.api.netsuite.com/app/site/hosting/restlet.nl?script=<SCRIPT_ID>&deploy=<DEPLOY_ID>
   ```

   > The `<ACCOUNT-ID>` part of the host (e.g. `TSTDRV1234567` or `TSTDRV-1234567`) is used as the OAuth **realm** when you don't provide one explicitly.

---

## 🚀 Quick Start

```dart
import 'package:netsuite_connector/netsuite_connector.dart';

void main() async {
  // 1. Credentials (throws CredentialsException immediately if anything is blank)
  final credentials = Credentials.fromValues(
    consumerKey: 'consumer_key',
    consumerSecret: 'consumer_secret',
    token: 'token_id',
    tokenSecret: 'token_secret',
  );

  // 2. Handler — realm is your account ID (recommended)
  final handler = OAuthHandler(
    credentials: credentials,
    realm: 'TSTDRV1234567',
  );

  // 3. Client
  final client = NetsuiteClient(handler: handler);

  final url = Uri.parse(
    'https://TSTDRV-1234567.restlets.api.netsuite.com'
    '/app/site/hosting/restlet.nl?script=123&deploy=1',
  );

  // 4. Use it!
  final data = await client.getJson(url);
  print(data);

  client.close();
}
```

---

## 🧱 Core Classes

| Class | Purpose |
|---|---|
| `Credentials` | Immutable, validated set of the 4 OAuth values. |
| `OAuthHandler` | Signs every outgoing request with OAuth 1.0a (adds the `Authorization` header). |
| `NetsuiteClient` | `http.BaseClient` subclass exposing all verbs + JSON helpers + typed errors. |
| `Signature` | Low-level HMAC signature computation (used internally). |
| `RequestHandler` | Abstract contract + shared OAuth helpers (nonce, timestamp, encoding, realm derivation). |
| `SignatureMethod` | Enum: `HMAC_SHA1`, `HMAC_SHA256`, `HMAC_SHA384`, `HMAC_SHA512`. |

---

## 📖 Usage Guide

### 1. Creating Credentials

**Recommended — named, null-safe parameters:**

```dart
final credentials = Credentials.fromValues(
  consumerKey: 'consumer_key',
  consumerSecret: 'consumer_secret',
  token: 'token_id',
  tokenSecret: 'token_secret',
);
```

**Legacy map constructor (backwards compatible with v1.x):**

```dart
final credentials = Credentials({
  'consumer_key': 'consumer_key',
  'consumer_secret': 'consumer_secret',
  'token': 'token_id',
  'token_secret': 'token_secret',
});
```

Both forms **fail fast**: a missing key or a blank value throws a `CredentialsException` right away, instead of producing a confusing HTTP 401 later. Secrets are masked in `toString()` so they never leak into logs.

> 💡 Keep secrets out of source code — load them from environment variables, a secret manager, or a git-ignored config file.

### 2. Creating the OAuth Handler

```dart
final handler = OAuthHandler(
  credentials: credentials,
  realm: 'TSTDRV1234567',                  // optional but recommended
  hash: SignatureMethod.HMAC_SHA256,       // default; NetSuite RESTlets also accept HMAC_SHA1
  version: '1.0',                          // OAuth protocol version
);
```

#### Realm support

The OAuth `realm` is your NetSuite **account ID** (e.g. `TSTDRV1234567`).

- **Explicit (recommended):** pass `realm: 'TSTDRV1234567'` — deterministic and works even behind proxies or custom hosts.
- **Automatic:** omit `realm` and it is derived from each request's host:
  `https://TSTDRV-1234567.restlets.api.netsuite.com/...` → realm `TSTDRV_1234567`.

### 3. Creating the Client

```dart
final client = NetsuiteClient(
  handler: handler,
  timeLimit: const Duration(seconds: 30),  // default: 15s
  httpClient: null,                        // optionally inject a custom http.Client
);
```

`NetsuiteClient` extends `http.BaseClient`, so it can be used anywhere a standard HTTP client is expected. Call `client.close()` when you're done.

---

## 🌐 HTTP Methods

Every verb returns a `Future<http.Response>` on success (status < 400) and throws a typed `NetsuiteException` on failure.

### GET

```dart
// Raw response
final response = await client.get(url);
print(response.statusCode);
print(response.body);

// Decoded JSON map in one call
final data = await client.getJson(url);
print(data['name']);
```

### POST (create)

```dart
// Map/List bodies are JSON-encoded automatically (Content-Type: application/json)
final response = await client.post(url, body: {'name': 'John Doe', 'email': 'john@example.com'});

// Or be explicit:
final created = await client.postJsonAndDecode(
  url,
  body: {'name': 'John Doe', 'email': 'john@example.com'},
);
print('Created id: ${created['id']}');
```

### PUT (update)

```dart
final updateUrl = Uri.parse('$url&id=42');

final response = await client.put(updateUrl, body: {'name': 'Jane Doe'});

// Or send + decode in one call:
final updated = await client.putJsonAndDecode(updateUrl, body: {'name': 'Jane Doe'});
```

### PATCH (partial update)

```dart
final response = await client.patch(updateUrl, body: {'email': 'jane@example.com'});
```

### DELETE

```dart
final response = await client.delete(Uri.parse('$url&id=42'));
if (response.statusCode == 200 || response.statusCode == 204) {
  print('Record deleted.');
}
```

### HEAD

```dart
final response = await client.head(url);
print('Server is up: ${response.statusCode == 200}');
```

### Custom headers & raw bodies

```dart
await client.post(
  url,
  body: '<item><name>Rustic Rope Canister</name></item>',   // String sent as-is
  headers: {
    'Content-Type': 'application/xml',
    'Accept': 'application/xml',
  },
);
```

### Query parameters

Append them to the URI — they are included in the OAuth signature automatically:

```dart
final urlWithParams = url.replace(queryParameters: {
  ...url.queryParameters,
  'search': 'customer',
  'limit': '50',
});
final results = await client.getJson(urlWithParams);
```

---

## ⚠️ Error Handling

All failures surface as **typed exceptions** under one base class, `NetsuiteException`:

```
NetsuiteException (abstract base)
├── CredentialsException        — bad/missing credential values (thrown at construction)
├── InvalidMethodException      — unsupported HTTP method
├── OAuthSignatureException     — request could not be signed
├── NetsuiteConnectionException — DNS/socket/connection failure (has .cause)
├── NetsuiteTimeoutException    — server didn't respond within timeLimit (has .timeLimit)
├── NetsuiteFormatException     — response body wasn't valid/expected JSON
└── NetsuiteResponseException   — HTTP status >= 400 (has .response, .statusCode, .errorCode, ...)
```

### Catch everything simply

```dart
try {
  final data = await client.getJson(url);
} on NetsuiteException catch (e) {
  print('NetSuite call failed: ${e.message}');
}
```

### Handle precisely (recommended)

```dart
import 'package:netsuite_connector/netsuite_connector.dart';

Future<Map<String, dynamic>?> fetchCustomer(NetsuiteClient client, Uri url) async {
  try {
    return await client.getJson(url);
  } on NetsuiteResponseException catch (e) {
    if (e.isNotFound) {
      return null;                                   // customer doesn't exist
    } else if (e.isPermissionError) {
      throw Exception('Check TBA role permissions.'); // 401 / insufficient perms
    } else if (e.isSignatureExpired) {
      throw Exception('Sync your clock — OAuth signature expired.');
    } else if (e.isDuplicateNonce) {
      return fetchCustomer(client, url);             // safe single retry
    } else if (e.isRateLimited) {
      await Future.delayed(const Duration(seconds: 5));
      return fetchCustomer(client, url);             // back off & retry
    } else if (e.isServerError) {
      return null;                                   // transient — retry later
    }
    rethrow;
  } on NetsuiteTimeoutException catch (e) {
    print('Timed out after ${e.timeLimit.inSeconds}s');
    rethrow;
  } on NetsuiteConnectionException catch (e) {
    print('Network problem: ${e.cause}');
    rethrow;
  }
}
```

### `NetsuiteResponseException` reference

| Member | Description |
|---|---|
| `response` | The full `http.Response` from NetSuite |
| `statusCode` | HTTP status code |
| `jsonBody` | Body decoded as `Map<String, dynamic>?` (null if not JSON) |
| `errorCode` | NetSuite error `code` from the standard error format (e.g. `INVALID_LOGIN`, `SSO: INVALID_RESPONSE`) |
| `errorMessage` | NetSuite human-readable `message` from the error body |
| `isPermissionError` | `401` or error code contains `INSUFFICIENT` |
| `isSignatureExpired` | `401` + expired-signature error (usually clock skew) |
| `isDuplicateNonce` | `401` + nonce replay rejection — retry safely |
| `isRateLimited` | HTTP `429` |
| `isServerError` | HTTP `5xx` |
| `isNotFound` | HTTP `404` (bad script/deploy ID) |
| `message` | Ready-to-log description incl. status + server detail |

---

## 🧰 JSON Helpers Reference

| Method | Verb | Returns |
|---|---|---|
| `getJson(url)` | GET | decoded `Map<String, dynamic>` |
| `postJson(url, body:)` | POST | raw `http.Response` (body auto-encoded) |
| `postJsonAndDecode(url, body:)` | POST | decoded `Map<String, dynamic>` |
| `putJsonAndDecode(url, body:)` | PUT | decoded `Map<String, dynamic>` |
| `NetsuiteClient.decodeJson(response)` | any | decode a response manually; throws `NetsuiteFormatException` on bad shape |

---

## ⏱️ Timeouts & Retries

```dart
final client = NetsuiteClient(
  handler: handler,
  timeLimit: const Duration(seconds: 30),
);

// Simple retry wrapper for transient failures
Future<T> withRetry<T>(
  Future<T> Function() action, {
  int attempts = 3,
}) async {
  for (var i = 0; i < attempts; i++) {
    try {
      return await action();
    } on NetsuiteException catch (e) {
      final transient = e is NetsuiteTimeoutException ||
          e is NetsuiteConnectionException ||
          (e is NetsuiteResponseException && (e.isRateLimited || e.isServerError));
      if (!transient || i == attempts - 1) rethrow;
      await Future.delayed(Duration(seconds: 2 << i)); // exponential back-off
    }
  }
  throw UnimplementedError(); // unreachable
}

final data = await withRetry(() => client.getJson(url));
```

---

## 🧪 Testing / Dependency Injection

Inject a mock or configured transport (e.g. `MockClient` from `package:http/testing`):

```dart
import 'package:http/testing.dart';

final mock = MockClient((request) async => http.Response('{"ok": true}', 200));

final client = NetsuiteClient(
  handler: OAuthHandler(credentials: credentials, realm: 'TSTDRV1234567'),
  httpClient: mock,
);
```

---

## 🔄 Migration from v1.x

| v1.x | v2.0.0 |
|---|---|
| `Credentials({...})` map only | Prefer `Credentials.fromValues(...)`; map constructor still works |
| No realm option | `OAuthHandler(realm: 'TSTDRV1234567')` — or rely on auto-derivation |
| Errors were strings / generic | Typed `NetsuiteException` hierarchy with `is*` helpers |
| Only GET/POST/DELETE | Full `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD` + JSON helpers |
| Default hash `HMAC_SHA1` | Default hash `HMAC_SHA256` (pass `hash: SignatureMethod.HMAC_SHA1` to keep old behavior) |
| No timeouts | Configurable `timeLimit` (default 15s) → `NetsuiteTimeoutException` |
| Nonce via `math.Random` | Cryptographically secure nonce (`Random.secure()`) |

Code that used `client.get/post/delete` continues to work; wrap calls in `try/on NetsuiteException` to gain precise error handling.

---

## 📁 Project Structure

```
netsuite_connector/
├── lib/
│   ├── netsuite_connector.dart      # public exports
│   └── src/
│       ├── credentials.dart         # validated OAuth credentials
│       ├── exceptions.dart          # typed error hierarchy
│       ├── signature.dart           # HMAC signature computation
│       ├── netsuite_client.dart     # the client (all verbs + JSON helpers)
│       ├── enum/
│       │   └── signature_method.dart
│       └── handlers/
│           ├── oauth_handler.dart   # OAuth 1.0a request signing (realm aware)
│           └── request_handler.dart # shared OAuth utilities
├── example/
│   └── netsuite_connector_example.dart
└── test/
```

---

## 💡 Tips & Troubleshooting

- **`401` with signature errors** → your machine's clock is skewed vs NetSuite (OAuth timestamps expire in ~5 minutes). Sync your clock (NTP).
- **`404 Not Found`** → wrong `script` / `deploy` query parameters, or the RESTlet isn't deployed to the account in the realm.
- **`INSUFFICIENT_PERMISSION`** → the role attached to your access token lacks permission for the script or the records it touches.
- **`ECMASCRIPT_FILE_EXCEEDS_SIZE_LIMIT` / script errors** → returned inside `NetsuiteResponseException.jsonBody`; inspect `errorCode` / `errorMessage`.
- **Behind a proxy?** Pass `realm` explicitly — auto-derivation relies on the real NetSuite host name.
- **Never log credentials.** `Credentials.toString()` masks secrets by design.

---

## 📄 License

Apache License 2.0 — see [LICENSE](./LICENSE).

## 🔗 Links

- [Changelog](./CHANGELOG.md)
- [Example](./example/netsuite_connector_example.dart)
- [Issues](https://github.com/pravinkumarravi/netsuite_connector/issues)
