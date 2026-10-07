# auth_repository

Signs people in and out, and knows who is signed in.

- `restore()` at launch uses the user kept from the last launch at once, so the app opens offline, then refreshes the account.
- `statusChanges` announces sign-in and sign-out, including a session the API ended.
- Every method that talks to the API throws an `ApiException` on failure.
