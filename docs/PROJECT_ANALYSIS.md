# Hisab Pro — Project Analysis and Requirements Synthesis

## 1. Product Vision

Hisab Pro is a premium, offline-first personal finance application for Android and iOS built from a single Flutter codebase. The application is designed as a secure local accounting system for managing income, expenses, accounts, loans, people, budgets, categories, reports, backups, and multi-user profiles without internet dependency.

The product is intentionally not a lightweight expense tracker. It is a complete personal ledger and financial control system with: 

- strict local-first data ownership
- encrypted database storage
- multiple user profiles on one device
- strong local authentication
- immutable financial event tracking
- offline reporting and analytics
- backup/restore with authenticated encryption
- premium UX for personal finance management

The design must prioritize correctness, security, and long-term data integrity over convenience or “quick UI wins.”

---

## 2. Requirements by category

### 2.1 Core technology constraints

The project must use:

- Flutter + Dart stable
- Material Design 3
- Riverpod for state management and DI
- GoRouter for navigation
- SQLite + SQLCipher encryption
- Drift or similar typed SQLite abstraction
- Flutter Secure Storage for protecting keys
- Local authentication for biometrics
- Freezed / JSON serializable where useful
- FL Chart for analytics
- Intl for localization and currency formatting

Explicit non-goals and prohibitions:

- no Firebase or cloud database
- no online auth
- no internet dependency
- no analytics/tracking SDK
- no remote API requirement for basic app functionality

This creates a strong offline-only architecture and means the app must be resilient from the very first launch without network access.

### 2.2 Application architecture requirements

The app must follow Clean Architecture, with clearly separated:

- presentation layer
- application/business logic layer
- domain layer
- data layer
- database layer
- security layer
- shared UI components

It also requires repository pattern, dependency injection, reusable components, and type-safe data models. The business logic must not live inside widgets. Business rules such as loan balance computation, transfer validation, and identity ownership checks must be enforced in repositories and use cases rather than at UI-only level.

### 2.3 Multi-user requirements

The app must support several local profiles on the same device. Each user profile must be completely isolated:

- unique username and full name
- profile picture/avatar
- local PIN/password
- optional biometric unlock
- profile edit, deletion, switch, lock
- user-specific settings

The design must use strict user ownership validation not just UI filtering. Best practice is per-user encrypted database file plus per-user key. This is not just a preference; it is a necessary security and integrity requirement because the app is intended for a family or shared device environment.

### 2.4 Security requirements (highest priority)

The specification explicitly says this is highest priority and must not be treated as optional.

Mandatory requirements:

- SQLCipher encryption at rest
- strong random key generation
- Android Keystore / iOS Keychain for key storage
- Argon2id-based PIN/password derivation with unique salts
- biometric local authentication
- automatic lock after inactivity
- manual lock
- failed login throttling
- secure session handling
- memory clearing where practical
- no private financial data in logs
- no plaintext credentials or keys in source code or SharedPreferences
- app switcher / screenshot protection where possible
- database integrity checks
- safe profile deletion and key destruction
- secure database migration

Important nuance: biometrics should unlock a key that protects the actual database key, not replace the actual encryption architecture. This means the biometric layer is a gate to the secure storage tier, not the database itself.

### 2.5 Dashboard requirements

The dashboard must show:

- available balance
- total income
- total expenses
- total loans given
- total loans taken
- receivables/payables
- monthly savings
- net worth

It also needs charts, recent transactions, reminders, quick actions, account overview, and monthly/yearly filtering. Calculations must rebuild from ledger data immediately after add/edit/delete/restore operations.

### 2.6 Accounts and transfers

Users must be able to manage multiple account types and transfer funds between them. Transfer entries must be modeled as linked debit and credit events and must not count as income or expense. A transfer is not a financial “gain” or “loss”; it is a movement between internal accounts.

### 2.7 Income and expense modules

Complete tracking is required for both. Each record includes amount, title, category, account, date, time, payment method, person/company, notes, and optional attachment. The application must provide search, filters, summaries, and defaults with custom categories. Expense reporting includes daily/weekly/monthly/yearly category summaries.

### 2.8 Loan management (core feature)

Loan management is a flagship module with two types:

- loan given
- loan taken

Each loan needs person data, amount, dates, status, account linkage, notes, and repayment history. Partial, multiple, and full repayments must be supported, and each repayment must produce an immutable linked financial event. Original loan amounts must never be overwritten. Prevent overpayment and duplicate repayment. Interest may be applied but the loan principal is not treated as income or expense.

### 2.9 Contacts/people management

Every person record must be able to aggregate financial relationships, including total money lent/borrowed, person-wise balances, loan history, and transaction history. A person may have multiple loans.

### 2.10 Budget management

Users need monthly budgets and category-specific budgets. Budgets must calculate spent amounts, remaining balances, and utilization percentages, with local reminders when thresholds are reached.

### 2.11 Reports and analytics

Reports must support daily/weekly/monthly/quarterly/yearly/custom ranges. They must include income, expenses, savings, cash flow, account-wise balances, category breakdowns, loan reports, person-wise balances, and export to local PDF/CSV without internet. The reports must be generated from source data, not static placeholders.

### 2.12 Search and filter system

Global search and filters must work offline across all major financial entities. This requires a proper searchable index strategy or database-layer query design rather than ad hoc UI filtering.

### 2.13 Backup and restore

The app must support encrypted backup export/import, full application backup, user-specific backup, verification, versioning, restore confirmation, and integrity validation after restoring. Use authenticated encryption such as AES-256-GCM with keys derived via Argon2id from a user-provided password. The app must never silently overwrite data without explicit confirmation. Include a backup-before-restore option.

### 2.14 Premium UX requirements

The visual design must be modern, minimal, and premium. It should include:

- Home / Transactions / Loans / Reports / Settings bottom navigation
- floating quick-action button for common transactions
- reusable balance cards, forms, empty states, skeletons, confirmation dialogs
- dark/light/system themes and accent colors
- responsive layouts and polished micro-interactions

### 2.15 Currency and localization

Default currency is PKR. App supports configurable currencies, English and Urdu, RTL interface, localized formats, and integer minor-unit accounting for money. This means values must not be stored as floating-point in business logic. Interest and currency calculations must use exact decimal arithmetic.

### 2.16 Database design requirements

The database must be normalized and ledger-oriented. Required tables are:

- user_profiles
- accounts
- categories
- transactions
- transfers
- people
- loans
- loan_repayments
- budgets
- budget_categories
- attachments
- reminders
- app_settings
- audit_events

The app must use foreign keys, indexes, unique constraints, migration versioning, transactions, and referential integrity. It must prevent cross-user data leakage, invalid repayments, duplicate transactions, and inconsistent totals.

### 2.17 Performance and reliability requirements

The app must handle large transaction history efficiently. It must support pagination, avoid unnecessary rebuilds, run heavy jobs off the main thread, handle app termination, migration failure, and atomic database transactions safely, and remain fully functional offline.

### 2.18 Testing requirements

The project requires:

- unit tests for math and business rules
- database encryption and migration tests
- widget tests for screens and flows
- integration tests for complete workflows
- cross-platform validation for Android and iOS

### 2.19 Development workflow requirements

The specification mandates phased development with milestone review after each phase. It explicitly forbids generating the full application in a single dump and requires that each phase be validated via analysis and tests before continuing.

### 2.20 Final delivery requirements

Final delivery includes complete source code, Android/iOS readiness, encrypted local database, robust multi-user system, premium UI, secure backup, tests, documentation, installation instructions, known limitations, and final built application output.

---

## 3. Architectural interpretation

The key architectural themes in the spec are:

1. Local-first financial accounting, not cloud-first convenience.
2. Security as a primary design component, not a feature layer layered at the end.
3. Strict user tenancy and data ownership boundaries.
4. Financial correctness and traceability of every monetary movement.
5. Offline data durability over remote features.
6. Premium product quality and business-grade reliability.

The application is effectively a local ledger system with strong user security boundaries. This is more similar to a secure, offline personal accounting suite than a typical mobile app.

---

## 4. High-level architecture summary

### Recommended architecture

- Presentation: Flutter UI using Material 3, reusable components, GoRouter screens, Riverpod providers
- Application: use cases, state controllers, validation, async orchestration
- Domain: entities, value objects, financial rules, repositories interfaces
- Data: repositories implementing SQL access, encryption wrappers, backup logic
- Database: SQLite with SQLCipher via the currently selected `sqflite_sqlcipher` abstraction. Drift's encrypted adapter was not usable because it requires a GitHub fetch; the app still needs an actual encrypted-open implementation and verification.
- Security: key management, biometric gate, lock timer, throttling, profile isolation
- Shared: constants, localization, formatting, validation helpers, charts, file paths

### Architectural emphasis

The application should be structured around a ledger-first model:

- every income/expense/transfer/loan repayment is recorded as a financial event
- balances are derived from events and validated against account totals
- loan repayments remain events linked to the original loan
- transfer events are distinct from income and expense events
- corrections use reversal logic or safe adjustment records instead of overwriting history

This is critical because the product is a real accounting system, not a simple budgeting app.

---

## 5. Database and security summary

The database is the core of the system. Requirements demand:

- encrypted local data
- per-user isolation
- account and category separation
- immutable transaction facts
- validated repayment flows
- audit trails

The recommended model is that each user profile owns:

- one encrypted database file, or
- one database with encrypted tables and per-user key
- strong key management through device secure storage

The specification explicitly prefers separate encrypted databases per profile with separate keys, and this is the most robust architecture for data isolation.

---

## 6. Risks and compatibility concerns

### 6.1 SQLCipher + Flutter compatibility

This is the most important dependency risk. Drift and SQLCipher need to be integrated in a way that is compatible with the target platform and stable Flutter version. If the chosen SQLCipher package is not maintained or if the platform-specific binaries are problematic, the app can face build delays or runtime issues. Recommended approach:

- verify the latest stable package compatibility before implementation
- prefer a maintained SQLCipher integration package
- run Android and iOS build verification before merging database work

### 6.2 Argon2id support in Dart/Flutter

Argon2id is required, but Dart itself does not have a native package guarantee for all versions. The project must select a verified, maintained Argon2 implementation compatible with Flutter and not rely on a weak KDF or simplistic hashing. This is a major security architecture requirement and should not be deferred.

The configured environment uses Flutter 3.50.0 and Dart 3.14.0. Dependency resolution, static analysis, tests, and Android runtime validation are being performed against this toolchain; no security behavior is considered verified until its implementation and relevant tests pass.

### 6.3 Biometric API behavior differences

Android and iOS biometric flows differ significantly in UX and platform constraints. The app must handle biometric availability, fallback PIN flows, and secure key unlocking in a unified abstraction layer. If biometrics are unavailable, the app must still function safely with secure local authentication.

### 6.4 Local-only backup and restore complexity

Secure backup is not a trivial feature. It requires:

- authenticated encryption
- password-derived keys
- versioning
- verification
- restore safety checks
- conflict resolution logic

The app must not silently overwrite existing data. This requires a careful restore UX and review flow.

### 6.5 Ledger correctness and rounding

Because the app stores money in minor units and handles interest, implementation must avoid floating-point arithmetic. Wrong rounding or precision handling can distort balances, loans, and reports. This is a major source of financial defects.

### 6.6 Multi-user database boundaries

A naive design using a single database with UI-level filters is unsafe. The major risk is cross-user data leakage from repository-layer access or mistaken SQL filters. The strict fix is ownership validation in the data layer and secure key separation by profile.

### 6.7 Performance risk with large datasets

The app must support long transaction histories, exports, and search. Without indexing and paginated queries, the app could become slow or unreliable. The data model must be optimized from the start.

---

## 7. Missing or ambiguous requirements that need clarification

The specification is very comprehensive, but several practical decisions should be clarified before implementation begins:

1. Master/owner access model
   - Who is the owner profile?
   - Is there a single “master admin” who can manage all local profiles and recovery keys?
   - Should owner access be enforced by a device-level secret or a separate PIN?

2. Recovery policy for forgotten passwords or lost biometric credentials
   - Does the project support secure escrow or encrypted recovery keys?
   - Does the app allow a full-device reset with explicit user confirmation?

3. Backup restore conflict policy
   - Should the app compare hashes before restore?
   - Should backups be versioned by user profile and database schema version?

4. Loan interest treatment
   - Should interest be tracked as a financial event separate from the principal loan amount?
   - Is interest to be generated to a separate category or recorded as part of loan repayment events?

5. Attachment strategy
   - Are attachments stored as file references, blobs, or external file systems?
   - Should metadata be stored in SQLite with actual files under application storage?

6. Notification permission behavior
   - Are local reminders optional or required?
   - Are reminders device-level and user-specific?

7. Export policy
   - Is unencrypted CSV/PDF export allowed only as a per-report option or also as a full data export?
   - What is the user consent and warning flow?

8. Currency rules
   - Is each user limited to one active default currency or multiple currencies per account?
   - Should conversion rates be manually entered or fixed to PKR?

9. Data deletion policy
   - Should “delete profile” remove all data immediately or keep encrypted backup first?
   - Are soft-delete and archive patterns required for accounts and loans?

10. App-level lock behavior
   - Should the lock timer be global or per profile?
   - Should there be a configurable lock-overrule for banking workflows?

These are not blockers for architecture design, but they affect the security and UX decisions significantly.

---

## 8. Recommended design decisions

### Preferred user isolation model

The most secure architecture is:

- one secure key store entry per profile
- one encrypted SQLite database per profile
- per-profile database path
- strict `user_id` validation in all DAO/repository access
- database-layer ownership checks on every query

This avoids the possibility of user leakage even if the app logic accidentally filters incorrectly in the UI.

### Preferred security pattern

- derive user PIN/password using Argon2id
- use the derived secret to unlock a randomly generated database key
- store the database key in Android Keystore / iOS Keychain under a profile-specific alias
- wrap the database connection with SQLCipher
- if the user is locked or biometric fails, the app does not expose data or database access

### Preferred financial correctness pattern

- store amounts as integer minor units
- maintain immutable accounting events
- use transaction boundaries for changes that affect multiple tables
- calculate totals from source ledger tables, not cached UI values
- use reversal records or status changes for corrections rather than edits to historical facts

---

## 9. Implementation-readiness assessment

The project is large and technically demanding, but the high-level architecture is well-defined and feasible. The major challenges are not UI design or feature breadth, but the combination of:

- local encrypted database handling
- strong per-user isolation
- correct financial accounting semantics
- secure key management
- data migration and backup safety

These factors will drive the implementation plan. The project should begin with security, database, and profile architecture before feature modules are implemented.

---

## 10. Final assessment

Hisab Pro should be treated as a secure offline ledger application with premium UX and multi-user local ownership. The specification is extensive and realistic for a production mobile application when implemented in phases. The single most important architectural principle is: security and financial integrity must be designed at the database and repository boundaries first, then the UI can be built confidently on top of that foundation.

This specification does not support a “demo-first” approach. It requires disciplined, phase-based development with strict validation and documentation after every phase.
