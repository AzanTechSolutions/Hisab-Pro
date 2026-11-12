# Hisab Pro Security Architecture

## 1. Security objective

The security model for Hisab Pro must be designed as a first-class system requirement. The app stores personal financial data, local profile data, and user-specific secrets on a private device. Because it is fully offline, all sensitive information must be protected locally with strong encryption and strict access control.

The core principle is simple:

- do not trust UI state alone
- do not trust any single filter to protect data
- protect data at rest, in memory, and at access boundaries
- isolate user data by profile and key

---

## 2. Threat model

The primary threats include:

- unauthorized access to app data on a stolen device
- cross-user data leakage on shared devices
- compromised PIN or local authentication bypass
- extraction of database keys from app storage
- stale session access after app backgrounding
- malicious restore or backup tampering
- failed migration or database corruption
- screenshots or app-switcher previews of sensitive screens

The system should be designed to reduce the impact of each of these risks.

---

## 3. Security layers

### 3.1 Secure device layer

Use native secure storage:

- Android: Keystore + AES key wrapping
- iOS: Keychain services

This is required to hold the database encryption keys, profile keys, and local secrets without exposing them in plain app storage.

Important rule: do not store encryption keys in SharedPreferences or plain SQLite metadata tables.

### 3.2 User authentication layer

The app must support:

- profile PIN/password
- optional biometric authentication
- activity-based automatic lock
- manual lock button
- failed attempt throttling

The biometric layer is not the actual security boundary. It should unlock a securely stored profile key or session token without replacing the underlying encryption architecture.

### 3.3 Database encryption layer

Use SQLCipher for the database file. Recommended architecture:

- user enters local credentials
- Argon2id derives a user key
- the user key unlocks a random database key stored in secure storage
- SQLCipher opens the database with the database key
- repository operations act only on the unwrapped user-scoped DB connection

This means the database itself is protected at rest even if someone obtains the file outside the app.

### 3.4 Multi-user isolation layer

The app must enforce user isolation in the following ways:

- separate profile records
- separate database or fully isolated encrypted state per user profile
- profile-specific secure storage aliases
- `user_id` validation in every repository call
- database-level ownership constraints and query filters
- session lock when profile is switched or locked

The UI can help, but it is never sufficient protection.

### 3.5 Backup security layer

Backups must be encrypted with authenticated encryption, ideally AES-256-GCM. To derive the encryption key, use:

- user-supplied backup password
- Argon2id KDF with unique salt
- optional backup passphrase confirmation
- verification hash or metadata validation before restore

Never export plaintext financial records by default. Only allow an unencrypted CSV/PDF export when the user explicitly opts in and understands the risk.

### 3.6 Audit and operational integrity layer

The design should log minimal, sanitized audit events such as:

- profile switch
- failed login attempts
- profile delete
- backup create
- backup restore
- database migration
- loan repayment updates

This is important for accountability and debugging, but financial values should never be logged in plaintext.

---

## 4. Key derivation and storage

### 4.1 Argon2id requirement

The specification explicitly rejects a simple PIN hash. A real design must use a password-based key derivation function suitable for local authentication.

Recommended flow:

- generate unique random salt per profile
- derive a high-entropy key from PIN/password using Argon2id
- use the derived key to unlock the profile-scoped database key or vault key

This protects user credentials even in the event of RAM or local file exposure.

### 4.2 Encryption key storage

The app should store the key material in Android Keystore / iOS Keychain under a profile-specific alias. The keys should be wrapped or abstracted behind a secure storage service. They should never be placed directly into SharedPreferences or plain application directories.

---

## 5. Session security

The app should enforce:

- short inactivity timeout for locked sessions
- biometric prompt or PIN challenge when app resumes
- secure teardown of session data when a profile is switched or the app is backgrounded
- explicit lock from the UI
- device-level pause when lock is triggered

Any session/token used to represent the authenticated state should be short-lived and local-only.

---

## 6. Failed login throttling

The app must handle repeated wrong attempts carefully.

Recommended safeguards:

- count consecutive failed PIN attempts per profile
- add exponential backoff or temporary lockout after several failed attempts
- require longer unlock time after repeated failure
- allow biometric fallback only when authenticated and supported by policy
- never reveal whether the app is “definitely” in a locked or disabled state beyond the correct UX flow

This reduces brute-force pressure while still keeping the local experience usable.

---

## 7. Sensitive data protection in app

### 7.1 Logging restrictions

The app should not log:

- database keys
- raw PINs or passwords
- financial values in plaintext
- user profile details in debug output
- attachment file paths in debug logs if they contain personal details

Use structured logging with redacted values.

### 7.2 Screen protection

Where supported, enable:

- secure window flag for payment and profile screens
- no screenshot of sensitive app state if possible
- app switcher preview restrictions to avoid exposing balances or profile details

This is not a substitute for encryption, but it reduces local risk.

### 7.3 Memory and lifecycle hygiene

The app should clear or reduce sensitive data in memory when practical:

- null out temporary plaintext secret variables
- avoid caching secret material in long-lived state objects
- clear session state after lock or logout
- avoid leaving decrypted database keys in global providers unnecessarily

This is a best-effort requirement because memory sanitization is limited by the platform runtime.

---

## 8. Multi-user profile deletion and recovery

When a user profile is deleted:

- confirm deletion explicitly
- destroy the profile key in secure storage
- revoke any active DB key access
- remove the profile database from local storage or securely wipe it
- invalidate active session state
- create an audit event for the action

Do not leave recoverable plaintext or database key remnants in app storage.

---

## 9. Data migration security

Database migration is a sensitive area because data transformations can accidentally expose or corrupt data.

Requirements:

- migrations must be versioned
- migration should run within a transaction when possible
- integrity checks should run after migration
- migration failure should not leave app in partially migrated state
- profile keys must be preserved across migrations
- migration error should be visible to the user without exposing sensitive data

---

## 10. Backup restore safety

The app must not silently overwrite existing data. Restore flow should require:

- explicit user confirmation
- backup verification and integrity check
- schema version match or safe migration logic
- backup creation before restore (optional but recommended)
- clear operational warning before replacing data
- restore logs saved as sanitized audit entries

This is essential because a restore mistake could destroy the user’s financial records.

---

## 11. Platform-specific limitations and required disclosure

### Android

- Keystore is strong, but secure storage is still tied to the app device and user context.
- Biometric support may vary by device hardware and OS version.

### iOS

- Keychain is strong, but app data access depends on secure enclave and device settings.
- App protection features may differ by OS version and device capabilities.

### General limitation

No local-only app can guarantee recovery of encrypted data if the user forgets their credentials and no backup or recovery key exists. The app must document this clearly instead of pretending data is always recoverable.

---

## 12. Security design summary

The recommended architecture is:

- every user profile gets a unique key and encrypted workspace
- app stores keys in secure OS storage only
- database is encrypted with SQLCipher
- PIN/password is processed with Argon2id
- biometric unlock only grants access to a protected key, not a bypass of database encryption
- backups use AES-256-GCM plus Argon2id-derived keys
- user access is enforced at repository and database boundaries
- lock timers and audit coverage protect session integrity

This is the minimum viable secure architecture for the specification.

---

## 13. Security validation checklist

Before implementation is considered production-ready, verify:

- profile data cannot be accessed across users
- key material is not stored in SharedPreferences
- database encryption is enforced at rest
- biometric flow unlocks secure key material only
- failed login throttling works
- restore cannot overwrite without confirmation
- profile deletion destroys key and data access
- backups are authenticated and verifiable
- logs contain no plaintext financial values

Without these checks, the app cannot be considered secure enough for the requested use case.
