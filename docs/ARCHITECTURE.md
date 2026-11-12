# Hisab Pro Architecture

## 1. Architectural goal

Hisab Pro is a secure, offline-first personal finance platform built as a single Flutter codebase for Android and iOS. The system architecture must support:

- multiple local users on the same device
- strict profile isolation
- encrypted local persistence
- ledger-based accounting
- offline reporting and analytics
- backup and restore with strong encryption
- maintainable feature modularity

The architecture must be resilient, production-grade, and oriented around correctness rather than demo convenience.

---

## 2. Architectural principles

### 2.1 Clean architecture

The project should be separated into the following layers:

1. Presentation layer
   - screens, widgets, forms, navigation, theming
   - Flutter UI only
2. Application layer
   - state controllers, use cases, validation, orchestration logic
   - business workflow coordination
3. Domain layer
   - entities, value objects, enums, repository interfaces
   - core finance rules
4. Data layer
   - repositories, database access, backup/restore services, file storage wrappers
5. Database layer
   - SQLite/SQLCipher access, migrations, connection management
6. Security layer
   - secure storage, biometric gate, key derivation, lock manager, profile validation
7. Shared components
   - formatting, routing, constants, charts, adapters, validators

### 2.2 Repository pattern

Repositories will provide the abstraction boundary between domain logic and data access. This helps enforce:

- user ownership validation
- precise SQL access
- centralization of encryption handling
- consistent backup and migration support

### 2.3 Dependency injection

Riverpod will be used for:

- services registration
- repository/providers
- database provider
- security provider
- profile session provider
- notification and backup providers

This keeps the app modular and testable.

---

## 3. System overview

High-level runtime flow:

- App starts
- session manager checks whether a user is already unlocked
- if no profile is active, the app shows profile selection or authentication
- user chooses a profile
- secure storage provides profile key material
- database connection opens with SQLCipher using user key
- repositories validate `user_id` ownership on every operation
- use cases execute accounting logic
- dashboards and reports are computed from ledger tables
- exports, backups, and reminders run locally

The app never depends on remote APIs for core financial workflows.

---

## 4. Multi-user architecture

### 4.1 Design goal

The application must support multiple user profiles on one device without accidental cross-profile access. A UI filter is not enough.

### 4.2 Recommended model

Use per-user profile isolation:

- profile record in a master metadata store
- separate database for each user profile, or a single database with profile-scoped tables and per-profile encrypted keys
- distinct user encryption keys in secure storage
- unique profile-level session context
- strict `user_id` checks in every query and command

### 4.3 Master/owner access model

The specification calls for a protected owner/master access mechanism. Recommended design:

- a device-level master profile or owner account
- master profile has the authority to manage profiles, lock states, and recovery actions
- master profile is not the same as ordinary user data access
- owner access can be used for safe migration, profile creation, or managed restore operations

This must be documented clearly since it affects the trust boundary and recovery policy.

---

## 5. Security architecture integration

Security is not an isolated service; it is part of the app core.

### 5.1 Key management

Recommended flow:

- user enters PIN/password
- password is turned into a key using Argon2id with unique salt
- key is used to unlock a profile-specific database key
- database key is stored in Android Keystore / iOS Keychain
- database opens with SQLCipher
- biometric authentication may unlock the database key but should not replace the actual encryption model

### 5.2 Locking and session management

The app should support:

- manual lock
- inactivity-based lock
- profile lock status
- failed attempt throttling
- active session expiry
- secure session teardown on app backgrounding

### 5.3 Sensitive data handling

The app should avoid exposing:

- plaintext credentials in logs
- financial values in debug output
- raw encryption keys in SharedPreferences
- screenshots / app switcher previews for sensitive screens

---

## 6. Domain model and business logic

The domain layer should model key abstractions:

- UserProfile
- Account
- Category
- Transaction
- Transfer
- Person
- Loan
- LoanRepayment
- Budget
- Reminder
- Attachment
- AppSettings
- AuditEvent

### Domain responsibilities

- account balance calculations
- transaction validity checks
- transfer debit/credit consistency
- loan principal/repayment logic
- budget utilization math
- report generation logic
- ownership validation
- session-lock conditions

Business logic must be implemented as domain rules or use cases, not directly inside widgets.

---

## 7. Ledger-oriented accounting model

The application should model financial events as immutable ledger entries. This means:

- income is a transaction event with type income
- expense is a transaction event with type expense
- transfer is a transfer event paired with debit and credit entries
- loan repayment is an event linked to the loan record
- balances are derived from these events, not manually maintained as a separate single source of truth

This is critical because it makes the system auditable and rebuildable.

---

## 8. Folder structure proposal

```text
lib/
  app.dart
  main.dart

  core/
    constants/
      app_constants.dart
      currency_constants.dart
      route_names.dart
    database/
      database.dart
      migrations/
      dao/
      tables/
    errors/
      app_exception.dart
      failure.dart
    extensions/
      date_time_extension.dart
      money_extension.dart
      string_extension.dart
    security/
      key_manager.dart
      biometric_service.dart
      auth_gate.dart
      lock_manager.dart
      crypto_service.dart
    theme/
      app_theme.dart
      color_tokens.dart
      typography.dart
    router/
      app_router.dart
      app_routes.dart
    utils/
      money_utils.dart
      date_utils.dart
      file_utils.dart
      logger.dart
    widgets/
      base_screen.dart
      empty_state.dart
      loading_indicator.dart
      confirmation_dialog.dart
      value_card.dart

  features/
    authentication/
      presentation/
      application/
      data/
      domain/
    user_profiles/
      presentation/
      application/
      data/
      domain/
    dashboard/
      presentation/
      application/
      data/
      domain/
    accounts/
      presentation/
      application/
      data/
      domain/
    transactions/
      presentation/
      application/
      data/
      domain/
    income/
      presentation/
      application/
      data/
      domain/
    expenses/
      presentation/
      application/
      data/
      domain/
    categories/
      presentation/
      application/
      data/
      domain/
    loans/
      presentation/
      application/
      data/
      domain/
    contacts/
      presentation/
      application/
      data/
      domain/
    budgets/
      presentation/
      application/
      data/
      domain/
    reports/
      presentation/
      application/
      data/
      domain/
    analytics/
      presentation/
      application/
      data/
      domain/
    reminders/
      presentation/
      application/
      data/
      domain/
    backup/
      presentation/
      application/
      data/
      domain/
    settings/
      presentation/
      application/
      data/
      domain/

  shared/
    models/
      enums/
      value_objects/
    services/
      currency_service.dart
      localization_service.dart
      notification_service.dart
      export_service.dart
    components/
      balance_card.dart
      transaction_tile.dart
      loan_card.dart
      chart_panel.dart
      form_fields/
```

This folder layout is recommended. It may evolve as needed, but it keeps domain logic isolated and feature boundaries clear.

---

## 9. Development standards

### 9.1 Code standards

- use strict typing
- avoid dynamic where possible
- use meaningful names
- keep logic outside widgets
- avoid duplicate implementations
- keep feature modules self-contained
- create reusable UI building blocks rather than copying screens

### 9.2 Safety rules

- no silent overwrite of user data
- no cross-user queries without `user_id` enforcement
- no plaintext storage of keys or credentials
- no float arithmetic for financial values
- no production data in logs
- no fake or hardcoded financial totals
- no database writes without transaction boundaries when required

### 9.3 Testing and quality gates

All feature work should satisfy:

- unit tests for logic
- database tests for isolation and migration
- widget tests for key flows
- integration tests for financial workflows

After each phase, run analysis and relevant tests before moving forward.

---

## 10. Dependency map and responsibilities

### Selected package direction for implementation

The following is the intended stable dependency set for the production implementation and is aligned with the project requirements:

- Flutter stable + Dart SDK (required to be installed in the working environment)
- Riverpod 2.x for state and dependency injection
- GoRouter 14.x for navigation
- `sqflite_sqlcipher` for SQLite access backed by SQLCipher on Android and iOS. This is the current adapter choice because the official Drift encrypted adapter requires a GitHub dependency that could not be fetched in this environment.
- flutter_secure_storage 9.x for protected key storage
- local_auth 2.x for biometric unlock
- flutter_local_notifications 17.x for local reminders
- fl_chart 0.68.x for charting
- intl 0.19.x for formatting and locale support
- freezed + json_serializable for domain models and state serialization
- argon2 for Argon2id-based key derivation
- file_picker and path_provider for backup/export workflows

The configured environment uses Flutter 3.50.0 and Dart 3.14.0. Package resolution and Android runtime validation are being performed against this toolchain. Security behavior remains unverified until implemented and tested.

### Flutter / Dart

Base runtime and UI framework. Maintains app lifecycle, rendering, device access, and platform support.

### Riverpod

State management, dependency injection, and application-scoped providers. Handles profile session state, repositories, and business state.

### GoRouter

Navigation and route management. Keeps the app modular and testable while supporting custom transition logic.

### SQLCipher

Encrypted database storage. Provides at-rest encryption for the app database.

The `sqflite_sqlcipher` package is only a database integration dependency at this stage. The app does not yet open an encrypted database or verify encryption at rest; those behaviors must be implemented and tested before being claimed.

### flutter_secure_storage

Protects encryption keys and sensitive local secrets using platform secure storage.

### local_auth

Handles biometric authentication and device security gate.

### flutter_local_notifications

Supports local reminders and alerts for budgets and loan due dates.

### intl

Formats numbers, dates, and currencies consistently with locale and user settings.

### fl_chart

Generates premium dashboard and report charts.

### freezed / json_serializable

Model generation for immutable data classes and JSON serialization.

### file_picker / path_provider / permission_handler

Used for attachments, backup export/import, and local file access.

### package_info, device_info

Optional support for versioning or environment-specific behavior when needed.

---

## 11. Key technical risks and recommended solutions

### Risk: SQLCipher integration complexity

Solution: verify compatibility before code-heavy implementation, keep DB wrapper centralized, and isolate all database access behind repository interfaces.

### Risk: platform differences in secure storage and biometrics

Solution: wrap all security hardware access behind a single abstraction service with a stable interface.

### Risk: loose user scoping

Solution: enforce `user_id` at repository and database layer; never trust UI filters.

### Risk: incorrect financial math

Solution: use integer minor units and exact decimal arithmetic; all calculations in domain layer.

### Risk: backup overwrite

Solution: require explicit restore confirmation, hash verification, and pre-restore backup creation option.

### Risk: migration failures

Solution: introduce versioned migrations, preflight checks, and safe fallback strategy.

---

## 12. Recommended architectural decision summary

The project should use:

- Clean Architecture with feature folders
- Riverpod for state and DI
- SQLCipher-backed SQLite through `sqflite_sqlcipher`, behind the database/repository boundary
- secure-storage-backed profile keys
- biometric unlock with strong local-auth gate
- user-specific database key and data segmentation
- ledger-style immutable financial events
- strict repository-level ownership validation
- phased feature delivery with validation after each milestone

This architecture fits the specification and reduces the risk of future data leakage, financial bugs, or broken migrations.
