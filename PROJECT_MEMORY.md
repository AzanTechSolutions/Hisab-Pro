# Hisab Pro — Project Memory

**Last Updated:** 2026-11-16 (18:50 PKT)  
**Project:** Hisab Pro (Personal Budget & Accounting Management System)  
**Status:** All 7 Phases Complete — Custom AzanTech App Icon & Developer Branding Integrated — APK Recompiled — iOS Deployment Guide Added

---

## 1. Project Purpose & Architecture

### Purpose
Hisab Pro is a 100% offline-first, local-first personal finance and accounting management application for Android and iOS. Developed by **AzanTech Solutions** (Contact: +92 329 5892004, Website: https://azantechsolutions.pages.dev). Rather than a basic expense tracker, it is designed as a complete offline accounting ledger supporting multi-user isolation on the same physical device, strong at-rest encryption, debt/loan tracking, multi-currency formatting, budgets, local backup/restore, and English/Urdu localization. Zero cloud dependencies, zero external telemetry.

### Architecture
- **Pattern:** Clean Architecture with Feature-First modular structure.
- **Layers:**
  - **Presentation (`lib/features/*/presentation/`, `lib/core/widgets/`):** Flutter UI, Material 3 theming, GoRouter navigation, Riverpod UI bindings, FL Chart visualizations, AzanTech branding.
  - **Application / State Management (`lib/features/*/*_providers.dart`):** Riverpod StateNotifiers / Notifiers, use cases, business workflow orchestration.
  - **Domain (`lib/features/*/domain/`):** Pure Dart entities (`Account`, `Category`, `FinancialTransaction`, `AccountTransfer`, `Person`, `Loan`, `LoanRepayment`, `Budget`, `BudgetCategoryAllocation`, `FinancialSummaryReport`, `UserProfile`, `BackupManifest`, `AppSettingsState`, `AuditEvent`).
  - **Data / Services (`lib/features/*/data/`, `lib/shared/services/`):** Repositories (`AccountRepository`, `CategoryRepository`, `TransactionRepository`, `PeopleRepository`, `LoanRepository`, `BudgetRepository`, `ReportsRepository`, `ProfileManagerService`, `BackupService`, `SettingsRepository`, `ReminderService`, `ExportService`, `AuditRepository`).
  - **Database (`lib/core/database/`):** `sqflite_sqlcipher` instance management, 14-table DDL schemas (`database_schema.dart`), versioned migrations, PRAGMA integrity checks.
  - **Security (`lib/core/security/`):** `flutter_secure_storage` (Android Keystore / iOS Keychain), `crypto` (NIST SP 800-132 / RFC 2898 PBKDF2-HMAC-SHA256 100% pure Dart key-wrapping), `local_auth` (biometrics). Zero native FFI `.so` dependencies — fully portable across all Android architectures.
  - **Shared / Core (`lib/core/`, `lib/shared/`):** Error handling (`AppException`, `Failure`), logger (`AppLogger`), monetary arithmetic (`MoneyService`), responsive layout (`ResponsiveContainer`), CSV exports (`ExportService`).

---

## 2. Important Files

### Application Setup & Lifecycle
- `lib/main.dart` — App entrypoint; initializes Flutter bindings and wraps app in `ProviderScope`.
- `lib/app.dart` — Root `MaterialApp.router` as a `ConsumerWidget` watching `settingsNotifierProvider` with dynamic theme mode (`ThemeMode.system`, `light`, `dark`), dynamic locale (`en`, `ur`), and RTL directionality support.
- `lib/core/router/app_router.dart` — Route configuration (`/auth`, `/profiles`, `/dashboard`, `/accounts`, `/people`, `/budgets`, `/reports`, `/transactions`, `/transfers/add`, `/loans`, `/backup`, `/settings`, `/audit`).

### Android Native Packaging & Branding
- `azantech.ico` — Source brand icon at root.
- `assets/images/azantech_logo.png` — Scaled in-app asset for brand badges and settings.
- `android/app/src/main/res/mipmap-*/ic_launcher.png` & `ic_launcher_foreground.png` — Native Android launcher icons generated from `azantech.ico` for all screen densities.
- `android/app/src/main/res/values/ic_launcher_background.xml` — Adaptive icon background color (`#0F172A`).
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` — Adaptive icon definition.
- `android/app/src/main/kotlin/com/azantech/hisabpro/MainActivity.kt` — Clean `FlutterActivity` (FLAG_SECURE removed to fix black screen / screen recording issues).
- `build/app/outputs/flutter-apk/app-debug.apk` — Latest compiled Android APK with AzanTech icon and branding.

### Database & Persistence
- `lib/core/database/app_database.dart` — Required entity definitions, profile DB filenames, key alias helpers.
- `lib/core/database/database_schema.dart` — Complete DDL statements for all 14 tables and performance indexes.
- `lib/core/database/database_service.dart` — Concrete `sqflite_sqlcipher` lifecycle manager (`openProfileDatabase`, `verifyIntegrity`, `closeProfileDatabase`, `deleteProfileDatabase`).
- `lib/core/database/database_migration.dart` — Migration step abstraction and version plan.

### Security & Cryptography
- `lib/core/security/database_encryption_service.dart` — PBKDF2-based key-wrapping, password verification sentinel, biometric key delegation, and key destruction.
- `lib/core/security/key_derivation_service.dart` — 100% pure-Dart PBKDF2-HMAC-SHA256 key derivation (RFC 2898 compliant, zero native `.so` dependencies).
- `lib/core/security/secure_storage_service.dart` — Hardware-backed wrapper around `flutter_secure_storage`.

### Audit Trail & Event Logging (Phase 7)
- `lib/features/audit/domain/audit_event.dart` — Audit event entity.
- `lib/features/audit/data/audit_repository.dart` — Tamper-evident audit event persistence, category filtering, and retention purging.
- `lib/features/audit/audit_providers.dart` — Riverpod providers for active audit queries and filter category selection.
- `lib/features/audit/presentation/audit_log_screen.dart` — Interactive audit trail screen with category filter chips.

### Backup & Restore (Phase 6)
- `lib/features/backup/domain/backup_manifest.dart` — Metadata container for backup archives.
- `lib/features/backup/data/backup_service.dart` — Authenticated, encrypted `.hisab` backup creation (PBKDF2 + HMAC-SHA256), tamper detection, and PRAGMA integrity-checked restore.
- `lib/features/backup/presentation/backup_screen.dart` — Export and restore UI with password prompts, safety backup toggle, and file picking.

### Offline CSV Exports & Notifications (Phase 6)
- `lib/shared/services/export_service.dart` — RFC 4180 compliant CSV export generator.
- `lib/features/reminders/data/reminder_service.dart` — Local notification alerts for loan repayment due dates and budget warnings.

### Settings & Urdu RTL Localization (Phase 6)
- `lib/features/settings/domain/app_settings_state.dart` — State entity for currency, theme, language, biometric, auto-lock.
- `lib/features/settings/presentation/settings_screen.dart` — Settings dashboard.

### Tests
- `test/core/database/database_service_test.dart` — DB config and required entities.
- `test/core/security/database_encryption_test.dart` — Key derivation, wrapping, password verification, and unlocking.
- `test/features/user_profiles/profile_manager_test.dart` — Profile creation, duplicate prevention, and deletion key cleanup.
- `test/features/transactions/transaction_repository_test.dart` — Transaction ledger tests.
- `test/features/loans/loan_repository_test.dart` — Loan and repayment tests.
- `test/features/budgets/budget_repository_test.dart` — Budget tracking tests.
- `test/features/reports/reports_repository_test.dart` — Reports aggregation tests.
- `test/features/backup/backup_service_test.dart` — Encrypted backup/restore tests.
- `test/shared/services/export_service_test.dart` — RFC 4180 CSV export tests.
- `test/features/audit/audit_repository_test.dart` — Audit logging and retention tests.

---

## 3. Tech Stack

- **Framework & Language:** Flutter SDK (>=3.13.0 <4.0.0, running Flutter 3.50.0 / Dart 3.14.0)
- **State Management & DI:** `flutter_riverpod: ^2.6.1`
- **Navigation:** `go_router: ^14.3.0` (resolved to 14.8.1)
- **Local Encrypted Database:** `sqflite_sqlcipher: ^3.4.1` (SQLCipher SQLite encryption)
- **Key Storage:** `flutter_secure_storage: ^11.2.0` (Android Keystore / iOS Keychain)
- **Key Derivation:** `crypto: ^3.0.6` (PBKDF2-HMAC-SHA256, pure Dart — replaced `serverpod_argon2`)
- **Biometric Authentication:** `local_auth: ^3.0.2`
- **Charts & Visualization:** `fl_chart: ^0.68.0`
- **Localization & Formatting:** `intl: ^0.20.3`, `flutter_localizations`
- **Local Notifications:** `flutter_local_notifications: ^17.2.3`
- **Storage & Files:** `path_provider: ^2.1.6`, `path: ^1.9.0`, `file_picker: ^13.3.3`
- **Code Generation & Models:** `freezed: ^4.0.3`, `json_serializable: ^6.15.2`, `build_runner: ^2.17.1`
- **Testing & Quality:** `flutter_test`, `integration_test`, `mocktail: ^1.0.5`, `sqflite_common_ffi: ^2.3.4+4`, `flutter_lints: ^6.0.0`
- **Strictly Excluded:** Firebase, Supabase, Cloud DBs, remote APIs, external tracking/analytics SDKs.

---

## 4. Completed Work

- [x] Initialized Flutter project with core folders (`core`, `features`, `shared`, `docs`, `test`, `integration_test`).
- [x] Configured dependency set in `pubspec.yaml` and resolved versions in `pubspec.lock`.
- [x] Implemented M3 design system, tokens, and dark/light themes (`app_theme.dart`, `design_tokens.dart`).
- [x] **Phase 2 (Auth, Multi-Profile & Database Encryption):**
  - Concrete DDL schema for all 14 tables in `database_schema.dart`.
  - Database service managing isolated database files (`hisab_<profileId>.db`).
  - PBKDF2-HMAC-SHA256 key wrapping and verification sentinel in `database_encryption_service.dart`.
  - Profile manager service with default accounts & categories seeding.
  - Multi-profile selector & creation screens with PIN & Biometric setup.
  - AuthGate with custom keypad, lockout timer, and biometric unlock.
- [x] **Phase 3 (Accounts, Income, Expense & Ledger Engine):**
  - Account domain & repository with safety checks (prevent deletion if records exist).
  - Category domain & repository.
  - FinancialTransaction & AccountTransfer domain entities.
  - TransactionRepository enforcing atomic income/expense account adjustments, linked internal transfers (debit/credit without income/expense skew), and atomic reversal on transaction deletion.
  - AccountListScreen, TransactionListScreen, TransactionFormScreen, TransferFormScreen.
- [x] **Phase 4 (People, Loans & Repayments Ledger):**
  - People/contacts management with aggregated lent, borrowed, receivable, payable, and net balances.
  - Loan domain entity preserving original principal.
  - Immutable repayment ledger tracking partial/full repayment events.
  - LoanRepository enforcing atomic balance transfers, overpayment validation, status auto-updates, and deletion reversals.
  - PeopleListScreen, LoanListScreen, LoanFormScreen, LoanDetailScreen.
- [x] **Phase 5 (Dashboard Upgrades, Budgets & Reports Analytics):**
  - Monthly budgets module with category allocations, live spending tracking, and warning threshold alerts.
  - ReportsRepository aggregating date-range financial summaries, 6-month cash flow datasets, and category pie slices.
  - ReportsScreen with interactive FL Chart BarChart and PieChart visualizations.
  - Upgraded DashboardScreen with live ledger metrics, accounts overview, quick actions, and recent transactions.
- [x] **Phase 6 (Backup/Restore, CSV Exports, Reminders & RTL Urdu):**
  - Authenticated encrypted backup and restore engine using PBKDF2 key derivation and HMAC tamper-verification.
  - RFC 4180 compliant CSV export engine for transactions, loans, accounts, and financial summary reports.
  - Local notifications service for loan repayment reminders and budget alerts.
  - Settings & preferences module supporting currency selection, theme toggling, Urdu/English switching with RTL, and biometric toggles.
- [x] **Phase 7 (Audit Logging, Native Security & Physical APK Build):**
  - Implemented `AuditEvent` domain entity and `AuditRepository` managing the `audit_events` table.
  - Created `AuditLogScreen` with category filtering and JSON metadata inspector.
  - All 34 unit tests passing with zero failures.
  - Successfully compiled debug Android APK.

---

## 5. Bugs Fixed

### BUG-001: `serverpod_argon2` native `.so` crash on Android (CRITICAL — Fixed Nov 16)
- **Symptom:** On physical Android device, creating a profile showed red error: `"Failed to load dynamic library 'libserverpod_argon2.so': dlopen failed: cannot locate symbol 'getauxval'"`.
- **Root Cause:** `serverpod_argon2` ships pre-built Zig-compiled native C libraries (`.so`) designed for Serverpod server-side Dart backends. On mobile Android's bionic libc, the `getauxval` symbol is not available in all API levels / architectures, causing `dlopen` to fail catastrophically.
- **Fix:** Replaced `serverpod_argon2` with pure-Dart `crypto` package implementing RFC 2898 PBKDF2-HMAC-SHA256 key derivation. Zero native dependencies. 100% portable across all Android/iOS/Web targets.
- **Files Changed:** `pubspec.yaml`, `lib/core/security/key_derivation_service.dart`, `lib/features/user_profiles/profile_manager_service.dart`, `lib/features/backup/presentation/backup_screen.dart`.

### BUG-002: Black screen during screen recording (Moderate — Fixed Nov 16)
- **Symptom:** User's screen recording showed 100% black pixels after launching Hisab Pro.
- **Root Cause:** `FLAG_SECURE` in `MainActivity.kt` tells Android OS to block all screen capture/recording (same as banking apps). Screen recorder captured pure black.
- **Fix:** Removed `FLAG_SECURE` from `MainActivity.kt`. App now renders normally in screen recordings and screenshots.
- **Files Changed:** `android/app/src/main/kotlin/com/azantech/hisabpro/MainActivity.kt`.

### BUG-003: `AppColors.textLight` not defined (Minor — Fixed Nov 16)
- **Symptom:** Build failed with `Member not found: 'textLight'` in `auth_gate.dart`.
- **Root Cause:** Loading screen referenced `AppColors.textLight` which doesn't exist in `design_tokens.dart`.
- **Fix:** Changed to `Colors.white`.
- **Files Changed:** `lib/features/authentication/auth_gate.dart`.

---

## 6. Current Work

- All phases (Phases 1 through 7) are 100% complete.
- All critical bugs fixed. 34/34 unit tests passing.
- Fresh APK compiled and ready for testing on physical mobile device.

---

## 7. Important Decisions & Invariants

- **NO EMULATOR EVER:** Emulators cause severe hardware throttling and overheat the user's laptop. All verification is done via headless unit testing and direct compilation of APKs for physical Android devices.
- **100% Local-First / Zero Cloud:** No Firebase, Supabase, analytics, or external servers. All data resides solely in local encrypted SQLCipher files.
- **Database-per-Profile Isolation:** Each user has their own distinct database file (`hisab_<profileId>.db`) encrypted with a distinct SQLCipher key.
- **Double-Entry Transfer Discipline:** Internal transfers between accounts debit from-account and credit to-account without affecting total income or expense.
- **Principal Immutability:** Repayments do not mutate or overwrite the initial loan principal; they are recorded as immutable event rows.
- **Integer Minor Units:** Monetary values stored as integers (e.g. 100000 = Rs. 1,000.00) via `MoneyService` to prevent floating-point calculation errors.
- **Pure Dart Crypto Only:** No native FFI crypto libraries (like `serverpod_argon2`). Only pure Dart `crypto` package for PBKDF2 key derivation, ensuring zero `dlopen` failures on any mobile device.
- **PBKDF2 Backup Integrity:** Backup archives are protected by PBKDF2-derived keys and tamper-evident HMAC envelopes; database restoration enforces `PRAGMA integrity_check`.

---

## 8. How to Test on Physical Android Phone

1. Locate the compiled APK on your laptop:
   `D:\AzanTech-Personal\Personal Budget Managment System\build\app\outputs\flutter-apk\app-debug.apk`
2. Connect your Android phone to the laptop via USB cable (or send the APK via WhatsApp Web, Google Drive, or Bluetooth).
3. On your Android phone, tap the APK file and select "Install". (If prompted, allow "Install unknown apps").
4. **IMPORTANT:** Uninstall any previous version of Hisab Pro first (since the old version had the broken `serverpod_argon2` native library cached).
5. Launch **Hisab Pro**:
   - Create your first profile with a master PIN and optional biometrics.
   - Test adding income, expenses, and accounts (Cash, Bank, Easypaisa, JazzCash).
   - Test giving and taking loans, and recording partial repayments.
   - Check the monthly budget progress and reports charts.
   - Switch language to Urdu (note the RTL layout) or switch themes (Light/Dark).
   - Test exporting an encrypted backup `.hisab` file and CSV ledgers.

---

## 9. Next Steps / Pending

- Physical device testing and user feedback incorporation.
- Production APK signing and release build (`flutter build apk --release`).
- Play Store listing preparation (if desired).

---

## 10. How to Use & Test on iPhone (iOS)

Apple enforces that iOS apps can only be compiled using Apple's Xcode toolchain, which runs natively on macOS. To run Hisab Pro on an iPhone, you have 3 practical options:

1. **Option A — If you or a friend have a Mac / MacBook:**
   - Copy this project to the Mac.
   - Run `flutter pub get` and `cd ios && pod install`.
   - Connect the iPhone via USB cable to the Mac.
   - Open `ios/Runner.xcworkspace` in Xcode, select your free Personal Apple ID under "Signing & Capabilities", and click **Run** (or execute `flutter run -d <iphone-device-id>`). The app will install directly onto the iPhone.

2. **Option B — Cloud CI/CD (No Mac Needed — e.g. Codemagic or GitHub Actions):**
   - Push this repository to GitHub.
   - Connect with **Codemagic** (which offers free monthly macOS build minutes for Flutter).
   - Codemagic builds the `.ipa` (iOS application package) in the cloud and sends you an installable link (via Apple TestFlight or Ad-Hoc provisioning).

3. **Option C — Sideloading via AltStore / Sideloadly (from Windows PC):**
   - Build unsigned or signed `.ipa` via cloud CI or remote Mac.
   - Use **AltStore** (installed on Windows) to sign and install the app onto your iPhone using your regular Apple ID without needing a paid developer account.
