# Hisab Pro Implementation Roadmap

## 1. Project approach

The specification requires a phased build. The application is too large and the security requirements are too sensitive to implement in one giant code dump. The project should proceed in discrete development milestones, with validation at the end of each phase.

Important rule from the specification:

- after each phase, explain what was implemented
- list files created or modified
- run Flutter analyze
- run relevant tests
- fix errors
- update documentation
- confirm completion before moving to the next phase

This document translates that requirement into a practical roadmap.

---

## 2. Phase 0 — Planning and architecture validation (before coding)

This phase is not an application feature phase but a mandatory design gate.

Objectives:

- confirm technology versions and package compatibility
- select the final Flutter/Dart stable combination and package set
- validate SQLCipher via `sqflite_sqlcipher`, secure storage, and biometric package compatibility
- confirm Argon2id package choice and security patterns
- finalize the user profile isolation model
- finalize the database schema and backup strategy
- complete architecture documentation and risk review

Outputs:

- architecture documentation
- database design document
- security design document
- package compatibility matrix
- project structure decisions

Exit criteria:

- package compatibility is verified
- secure storage pattern is approved
- encryption and user isolation architecture is documented
- no unresolved critical design gap

---

## 3. Phase 1 — Project setup and foundation

### Scope

- initialize Flutter project
- configure project structure
- set up Riverpod, GoRouter, Intl, Freezed, JSON serializable, FL Chart
- configure dependency injection skeleton
- define design system and theme tokens
- create database abstraction and migration framework
- define security service interfaces

### Deliverables

- Flutter project scaffold
- `core` layer skeleton
- `features` directory structure
- theme files
- database service provider
- secure storage abstraction
- router and app shell
- app constants and configuration helpers

### Validation

- `flutter analyze`
- check app boots without runtime errors
- confirm design system compiles
- validate package compatibility on Android and iOS targets

### Phase exit criteria

The project must compile cleanly and the architecture skeleton must be ready for feature work.

---

## 4. Phase 2 — Authentication and multi-user profiles

### Scope

- user profile creation and editing
- username and profile details
- PIN/password setup
- biometric enable/disable
- lock/unlock UI
- profile switching
- failure throttling
- inactivity lock
- profile deletion flow

### Critical backend work

- Argon2id-based credential derivation
- encrypted profile key management
- secure storage for user secrets
- user scoping for all repositories
- profile selection and session logic

### Deliverables

- auth features and profile management screens
- secure key wrapper service
- profile session manager
- biometric unlock service
- local authentication flow
- profile deletion and secure key destruction logic

### Validation

- unit tests for derived key logic and failed-attempt throttling
- database tests for profile isolation
- widget tests for login, profile switch, and lock behavior

### Phase exit criteria

Successful authentication and profile switching must work without cross-user leakage. The app must correctly handle locks and deletions.

---

## 5. Phase 3 — Accounts, income, expenses, and transaction engine

### Scope

- account creation and editing
- opening balances
- account transfers
- income and expense records
- category management
- transaction search/filter
- account and category summaries
- dashboard calculations

### Critical logic

- account balances derived from ledger events
- transfer events as debit/credit pair, not income/expense
- category-specific and account-specific totals
- transaction search filters
- exact arithmetic using minor-unit storage

### Deliverables

- `accounts` module
- `transactions` engine
- `income` module
- `expenses` module
- `categories` module
- dashboard data providers

### Validation

- unit tests for balance math, category calculations, transfer logic
- database tests for CRUD, validation, and ownership
- widget tests for add/edit transaction forms

### Phase exit criteria

Financial computations must be mathematically correct, and all data must remain isolated per user.

---

## 6. Phase 4 — People and loans

### Scope

- contacts/people management
- loan given
- loan taken
- repayment flow
- partial repayments
- full settlement
- overdue tracking
- person-wise summaries

### Critical logic

- loan principal remains immutable
- each repayment is a linked event
- remaining balance is derived from loan and repayments
- prevent duplicate and overpayment records
- maintain transaction integrity with account impact

### Deliverables

- `people` module
- `loans` module
- `loan_repayments` model and repository
- loan summary dashboards
- repayment entry UI and forms

### Validation

- unit tests for partial repayment and outstanding balance logic
- database transaction tests for repayment correctness
- integration tests for loan given and loan taken workflows

### Phase exit criteria

All loan scenarios work correctly, and repayment logic remains consistent with account balances and database integrity rules.

---

## 7. Phase 5 — Dashboard, budgets, analytics, and reports

### Scope

- premium dashboard
- monthly/yearly filters
- budget creation and category budgets
- budget utilization tracking
- local reminder notifications
- reports and charts
- PDF/CSV exports

### Critical logic

- all dashboard totals derived from source ledger data
- charts generated from actual transaction values
- budget logic must be correct across categories and months
- report generation must be local and offline

### Deliverables

- dashboard screens and analytics widgets
- budget module
- reports module
- export services
- reminder service

### Validation

- unit tests for totals, budget math, and report calculations
- widget tests for dashboard and report UI
- integration tests for reporting workflow

### Phase exit criteria

The app can present accurate financial insights from real local data and produce reports without internet connectivity.

---

## 8. Phase 6 — Backup, restore, localization, and polishing

### Scope

- encrypted backup export/import
- restore confirmation flow
- restore from backup with version validation
- CSV/PDF optional exports
- localization for English and Urdu
- RTL handling
- settings and user preferences
- app polish and premium UX refinements

### Critical logic

- backup encryption must use secure KDF and authenticated encryption
- restore must not silently overwrite data
- export permissions must be explicit and user-controlled
- date/currency formatting must be locale-aware

### Deliverables

- `backup` module
- restore workflow UI
- local export service
- localization configuration
- app settings and theme improvements

### Validation

- database tests for backup/restore
- security tests for backup encryption and verification
- widget tests for backup and restore flow

### Phase exit criteria

Backups and restores work securely and the app supports local currency and language preferences.

---

## 9. Phase 7 — Comprehensive testing, security audit, performance tuning, and final build validation

### Scope

- full unit test suite
- database integration suite
- widget tests for all critical flows
- integration tests for end-to-end financial journeys
- security audit
- performance tuning
- Android build preparation
- iOS build readiness review

### Deliverables

- test suite complete
- security audit findings documentation
- optimization updates
- final build verification notes
- known limitations list

### Validation

- `flutter analyze`
- targeted tests and relevant integration suites
- Android build validation
- iOS project validation and build review

### Phase exit criteria

The project is production-ready for the current implementation scope, with documentation and tested behavior established.

---

## 10. Required gates after each phase

After every phase, the team must:

1. explain what was implemented
2. list changes to files and modules
3. run Flutter analyze
4. run relevant tests
5. fix all errors
6. update documentation
7. confirm the phase is complete before starting the next one

This disciplined workflow is essential because the project combines security, accounting correctness, and multi-user isolation, which are not areas to “rough in and fix later.”

---

## 11. Critical implementation priorities

The project should prioritize in this sequence:

1. security architecture
2. multi-user isolation
3. database and schema correctness
4. account and transaction logic
5. loan system integrity
6. dashboard and reports
7. backup and restore
8. localization and polish
9. comprehensive testing

This order matters because later features depend on the correctness of lower-level financial and security systems.

---

## 12. Final delivery expectation

At the end of the roadmap, the app should be:

- secure and offline-first
- functionally complete for personal finance management
- supported on Android and iOS from a single codebase
- protected by encrypted local storage
- correct from an accounting perspective
- operationally reliable under multi-user use
- documented and tested

The roadmap is intentionally structured to avoid cumulative technical debt and to preserve product quality under strong security constraints.
