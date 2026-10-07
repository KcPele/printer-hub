# local_store

What the app keeps on the device.

- `SecureStore`: small secrets in the Keychain (iOS) or Keystore (Android). `InMemorySecureStore` stands in for it in tests.
- `SecureTokenStore`: the session's tokens, as the `TokenStore` the API client reads.

The job queue and offline printer profiles will live here too.
