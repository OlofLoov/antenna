## 1. Remember found logins

- [x] 1.1 `LoginPresence` keeps the service and account of each login found, behind a `Mutex`
- [x] 1.2 `CredentialStoring.hasLogin(for:accepts:)`, uncached by default; `CredentialStore` answers from `LoginPresence` and forgets a key on save and delete
- [x] 1.3 `SourceLoader.hasLogin` asks through it, keeping the Stalker MAC rule and "unreadable counts as here"
- [x] 1.4 `ForgetLoginsOnActivate` forgets everything when the app becomes active
- [x] 1.5 App unit tests count Keychain reads for a found, missing, deleted, unreadable and Stalker login

## 2. Verify

- [x] 2.1 The requirement this change adds has a test citing `source-management/login-checks-are-remembered`
- [x] 2.2 A before and after count of Keychain lookups is recorded in design.md
- [x] 2.3 /opsx:verify passes
