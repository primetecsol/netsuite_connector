import 'package:netsuite_connector/netsuite_connector.dart';

/// End-to-end example: GET / POST / PUT (update) / PATCH / DELETE with
/// production-style typed error handling.
Future<void> main() async {
  // ------------------------------------------------------------------
  // 1. Credentials — strongly typed, validated at construction time.
  // ------------------------------------------------------------------
  final credentials = Credentials.fromValues(
    consumerKey: 'your consumer_key',
    consumerSecret: 'your consumer_secret',
    token: 'your token',
    tokenSecret: 'your token_secret',
  );

  // The legacy map based constructor still works:
  // Credentials({
  //   'consumer_key': '...', 'consumer_secret': '...',
  //   'token': '...', 'token_secret': '...',
  // });

  // ------------------------------------------------------------------
  // 2. Client setup.
  // ------------------------------------------------------------------
  final handler = OAuthHandler(
    credentials: credentials,
    realm: '<ACCOUNT_ID>', // e.g. 'TSTDRV1234567' — optional; if omitted the
    // realm is auto-derived from the request host.
    hash: SignatureMethod.HMAC_SHA256, // HMAC_SHA1 also supported
  );

  final client = NetsuiteClient(
    handler: handler,
    timeLimit: Duration(seconds: 30),
  );

  final baseUri = Uri.parse(
    'https://<ACCOUNT_ID>.restlets.api.netsuite.com/app/site/hosting/restlet.nl',
  );

  try {
    // --------------------------------------------------------------
    // GET — raw response and decoded JSON helper.
    // --------------------------------------------------------------
    final getUri =
        baseUri.replace(queryParameters: {'script': '100', 'deploy': '1'});

    final getResponse = await client.get(getUri);
    print('GET  ${getResponse.statusCode}: ${getResponse.body}');

    final data = await client.getJson(getUri); // Map<String, dynamic>
    print('GET  json: $data');

    // --------------------------------------------------------------
    // POST — create a record (body auto-encoded as JSON).
    // --------------------------------------------------------------
    final postUri =
        baseUri.replace(queryParameters: {'script': '101', 'deploy': '1'});

    final created = await client.postJsonAndDecode(
      postUri,
      body: {'title': 'example', 'body': 'lorem ipsum'},
    );
    print('POST created id: ${created['id']}');

    // --------------------------------------------------------------
    // PUT — update (full replace) a record.
    // --------------------------------------------------------------
    final putUri = baseUri.replace(
        queryParameters: {'script': '102', 'deploy': '1', 'id': '100'});

    final updated = await client.putJsonAndDecode(
      putUri,
      body: {'id': 100, 'title': 'updated title'},
    );
    print('PUT  updated: $updated');

    // --------------------------------------------------------------
    // PATCH — partial update.
    // --------------------------------------------------------------
    final patched = await client.patch(putUri, body: {'title': 'patched'});
    print('PATCH status: ${patched.statusCode}');

    // --------------------------------------------------------------
    // DELETE — remove a record.
    // --------------------------------------------------------------
    final deleted = await client.delete(putUri);
    print('DELETE status: ${deleted.statusCode}');
  } on NetsuiteResponseException catch (e) {
    // NetSuite answered, but with an error status (4xx / 5xx).
    if (e.isSignatureExpired) {
      print('OAuth signature expired — check your system clock.');
    } else if (e.isDuplicateNonce) {
      print('Duplicate nonce — safe to retry the request.');
    } else if (e.isPermissionError) {
      print('Permission denied for script/deploy.');
    } else if (e.isNotFound) {
      print('RESTlet script/deploy not found.');
    } else if (e.isRateLimited) {
      print('Rate limited — back off and retry later.');
    } else if (e.isServerError) {
      print('NetSuite internal error (${e.errorCode ?? '-'}): '
          '${e.errorMessage ?? e.response.body}');
    } else {
      print('HTTP ${e.statusCode}: ${e.message}');
    }
  } on NetsuiteTimeoutException catch (e) {
    print('Timed out after ${e.timeLimit.inSeconds}s — retry?');
  } on NetsuiteConnectionException catch (e) {
    print('Network failure: ${e.message} (cause: ${e.cause})');
  } on NetsuiteFormatException catch (e) {
    print('Unexpected payload: ${e.message}');
  } on CredentialsException catch (e) {
    print('Bad configuration: ${e.message}');
  } on NetsuiteException catch (e) {
    // Any other package error.
    print('Connector error: $e');
  } finally {
    client.close();
  }
}
