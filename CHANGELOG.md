## 2.0.0

- Full rewrite with Dart null safety (SDK >=3.0.0).
- All HTTP verbs supported: GET, POST, PUT (update), PATCH, DELETE, HEAD, plus JSON helpers (`getJson`, `postJson`, `postJsonAndDecode`, `putJsonAndDecode`).
- OAuth `realm` support: set it explicitly via `OAuthHandler(realm: 'TSTDRV1234567')`; when omitted it is auto-derived from the request host.
- Typed exception hierarchy for easy error handling (`NetsuiteException`, `NetsuiteResponseException` with `isPermissionError` / `isSignatureExpired` / `isDuplicateNonce` / `isRateLimited` / `isNotFound` / `isServerError`, `NetsuiteTimeoutException`, `NetsuiteConnectionException`, `CredentialsException`, ...).
- Configurable request timeout (`timeLimit`) and injectable `http.Client` for testing.

## 1.0.0

- Initial version.
