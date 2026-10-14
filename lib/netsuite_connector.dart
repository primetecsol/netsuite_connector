/// A production-ready, null-safe Dart client for NetSuite RESTlets using
/// OAuth 1.0a (HMAC) request signing.
///
/// Quick start:
///
/// ```dart
/// import 'package:netsuite_connector/netsuite_connector.dart';
///
/// final credentials = Credentials.fromValues(
///   consumerKey: '...',
///   consumerSecret: '...',
///   token: '...',
///   tokenSecret: '...',
/// );
///
/// final client = NetsuiteClient(
///   handler: OAuthHandler(credentials: credentials),
/// );
///
/// final response = await client.get(uri);
/// ```
///
/// All errors are typed — catch [NetsuiteException] or one of its subclasses
/// ([NetsuiteResponseException], [NetsuiteTimeoutException],
/// [NetsuiteConnectionException], [CredentialsException], ...) for precise
/// error handling.
library netsuite_connector;

export 'src/credentials.dart';
export 'src/enum/signature_method.dart';
export 'src/exceptions.dart';
export 'src/handlers/oauth_handler.dart';
export 'src/handlers/request_handler.dart';
export 'src/netsuite_client.dart';
export 'src/signature.dart';
