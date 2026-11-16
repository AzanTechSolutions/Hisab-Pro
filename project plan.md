# PROJECT: HISAB PRO — Premium Offline Personal Finance Manager

Act as a Principal Software Architect, Senior Flutter Engineer, UI/UX Designer, Database Architect, and Mobile Application Security Engineer.

Your task is to design and build a production-quality, premium personal finance management application named **Hisab Pro**.

The application must work on BOTH Android and iOS using a single codebase.

This is a complete personal accounting system, not a basic expense tracker.

The application must be:
- 100% offline-first.
- Local database based.
- Fully encrypted at rest.
- Multi-user capable on the same device.
- Fast, responsive, and beautifully designed.
- Reliable for long-term financial record keeping.
- Built with scalable, maintainable architecture.

Do not create a demo, prototype, or UI-only application. Build real working functionality.

---

# 1. TECHNOLOGY STACK

Use modern, stable, production-ready technologies.

Core:
- Flutter (latest stable version).
- Dart (latest stable version).
- Material Design 3 with a completely customized design system.
- Riverpod for state management and dependency injection.
- GoRouter for navigation.
- SQLite with SQLCipher encryption for local database storage.
- Drift or an appropriate SQLite abstraction for type-safe database operations.
- Flutter Secure Storage for protecting encryption keys.
- Local Authentication for biometric authentication.
- Freezed and JSON Serializable where appropriate.
- FL Chart for charts and analytics.
- Local notifications for optional reminders.
- Intl for date, currency, and number formatting.

Before implementation, verify the latest compatible stable versions of all packages. Avoid abandoned packages and incompatible dependencies.

Do not use:
- Firebase.
- Supabase.
- Cloud databases.
- Remote APIs.
- Online authentication.
- Any mandatory internet connection.
- Any external analytics or tracking SDK.

The application must work without an internet connection from the first launch.

# 2. APPLICATION ARCHITECTURE

Use Clean Architecture with feature-based modular organization.

Separate:
- Presentation layer.
- Application/business logic layer.
- Domain layer.
- Data layer.
- Database layer.
- Security layer.
- Shared UI components.

Use repository pattern and dependency injection.

Keep business logic outside UI widgets.

Use reusable components and strict typing.

Suggested folder structure:

lib/
  core/
    constants/
    errors/
    extensions/
    security/
    database/
    theme/
    router/
    utils/
    widgets/

  features/
    authentication/
    user_profiles/
    dashboard/
    accounts/
    transactions/
    income/
    expenses/
    categories/
    loans/
    contacts/
    budgets/
    reports/
    analytics/
    reminders/
    backup/
    settings/

  shared/
    models/
    services/
    components/

  main.dart

Adapt this structure if a better architecture is justified.

# 3. MULTI-USER SYSTEM

Multiple users must be able to use the same application on the same physical device.

Implement:

- Create user profile.
- User full name.
- Profile picture or avatar.
- Unique username.
- User-specific PIN/password.
- Optional biometric unlock.
- Edit profile.
- Delete profile.
- Switch between users.
- Lock profile.
- User-specific application settings.

Each user must have completely separate financial records.

A user must NEVER be able to access another user's data accidentally or through ordinary application operations.

Implement strict user_id ownership validation at the repository and database levels.

Use a separate encryption key for each user profile.

Never rely only on filtering records in the UI for user isolation.

For additional security, consider separate encrypted database files per profile, with independently protected encryption keys.

The application must also support a protected owner/master access mechanism for managing local profiles.

# 4. SECURITY SYSTEM — HIGHEST PRIORITY

Security is not optional.

Implement:

1. SQLCipher database encryption.
2. Strong encryption key generation using a cryptographically secure random generator.
3. Secure encryption-key storage using Android Keystore and iOS Keychain through supported native secure-storage mechanisms.
4. Argon2id password/PIN derivation with unique salts and appropriate parameters.
5. Biometric authentication using native platform authentication.
6. Automatic application locking after configurable inactivity.
7. Manual lock button.
8. Failed login attempt throttling.
9. Secure session handling.
10. Clear sensitive data from memory where practical.
11. No financial information in application logs.
12. No plaintext credentials or database keys in source code.
13. No hardcoded encryption keys.
14. Protect sensitive app content from screenshots and app-switcher previews where supported.
15. Database integrity checks.
16. Secure profile deletion, including destruction of the corresponding encryption key.
17. Safe database migration procedures.

PINs must not be stored as plaintext.

Do not use a simple PIN hash without a suitable password derivation function.

Never store encryption keys directly in SharedPreferences.

Biometrics should unlock an appropriately protected encryption key, not replace the actual encryption architecture.

If the user forgets their password, provide a clear recovery policy. Do not pretend encrypted data can always be recovered without a recovery key.

Document platform-specific security limitations.

# 5. DASHBOARD

Create a premium dashboard with:

- Total available balance.
- Total income.
- Total expenses.
- Total loans given.
- Total loans taken.
- Outstanding receivables.
- Outstanding payables.
- Monthly savings.
- Net worth.

Add:

- Income vs expense chart.
- Monthly financial overview.
- Recent transactions.
- Upcoming loan repayment reminders.
- Quick action buttons.
- Account balance overview.
- Monthly and yearly filters.

Dashboard calculations must update immediately after adding, editing, deleting, or restoring financial records.

Use accurate calculations based on ledger data, not hardcoded values.

# 6. ACCOUNTS MANAGEMENT

Users should be able to create multiple financial accounts.

Examples:
- Cash.
- Bank account.
- Wallet.
- Easypaisa.
- JazzCash.
- Savings account.
- Custom account.

Features:
- Add account.
- Edit account.
- Delete/archive account.
- View current balance.
- Account transaction history.
- Transfer money between accounts.
- Account opening balance.

Transfers must be recorded as linked debit and credit entries.

A transfer must not incorrectly count as income or expense.

# 7. INCOME MANAGEMENT

Implement a complete income management system.

Fields:
- Amount.
- Title.
- Category.
- Account.
- Date.
- Time.
- Payment method.
- Person/company.
- Notes.
- Optional attachment.

Features:
- Add income.
- Edit income.
- Delete income.
- Search income.
- Filter by category.
- Filter by date.
- Filter by account.
- Income history.
- Monthly income summary.

Default categories:
- Salary.
- Business.
- Freelancing.
- Investment.
- Rental income.
- Gifts.
- Other.

Allow custom categories.

# 8. EXPENSE MANAGEMENT

Implement complete expense tracking.

Fields:
- Amount.
- Title.
- Category.
- Account.
- Date.
- Time.
- Payment method.
- Merchant/person.
- Notes.
- Optional attachment.

Features:
- Add expense.
- Edit expense.
- Delete expense.
- Search and filter.
- Daily expense summary.
- Weekly expense summary.
- Monthly expense summary.
- Yearly expense summary.
- Category-based expense charts.

Default categories:
- Food.
- Transport.
- Shopping.
- Bills.
- Rent.
- Healthcare.
- Education.
- Entertainment.
- Groceries.
- Travel.
- Other.

Allow users to create custom categories.

# 9. LOAN MANAGEMENT — CORE FEATURE

This is one of the most important modules.

Support two types:

A. LOAN GIVEN (Money I lent to someone).

B. LOAN TAKEN (Money I borrowed from someone).

For every loan record:

- Person's name.
- Phone number (optional).
- Loan amount.
- Loan date.
- Due date.
- Interest rate (optional, default zero).
- Account from/to which money was transferred.
- Description.
- Notes.
- Status.
- Repayment history.

Loan given:
- Track money lent.
- Track partial repayments.
- Track full repayments.
- Calculate remaining receivable amount.
- Show overdue loans.
- Show person-wise outstanding balance.

Loan taken:
- Track money borrowed.
- Track partial repayments.
- Track full repayments.
- Calculate remaining payable amount.
- Show due and overdue amounts.

Repayment system:

Every repayment must create a separate immutable financial event linked to the original loan.

Support:
- Partial repayment.
- Multiple repayments.
- Full settlement.
- Repayment date.
- Repayment account.
- Repayment notes.
- Repayment history.

Example:

Loan given: Rs. 50,000

First repayment: Rs. 10,000

Second repayment: Rs. 15,000

Remaining receivable: Rs. 25,000.

Never replace the original loan amount with the remaining balance.

Prevent overpayment and duplicate repayment errors.

Implement proper transaction handling so loan records, repayments, and account balances remain consistent.

Do not count loan principal as income or expense.

Only record interest separately when applicable.

# 10. CONTACTS / PEOPLE MANAGEMENT

Create a people management module.

Fields:
- Full name.
- Phone number.
- Address (optional).
- Notes.
- Profile image (optional).

Show:
- Total money lent to person.
- Total money borrowed from person.
- Outstanding receivable.
- Outstanding payable.
- Complete transaction history.
- Complete loan history.

One person can have multiple loans.

# 11. BUDGET MANAGEMENT

Implement monthly budgets.

Users can:
- Set monthly overall budget.
- Set category-wise budgets.
- View spent amount.
- View remaining budget.
- View budget utilization percentage.
- Receive local notifications when budget reaches configurable thresholds.

Example:
Monthly food budget = Rs. 20,000.

Spent = Rs. 15,000.

Remaining = Rs. 5,000.

# 12. REPORTS AND ANALYTICS

Create a professional reporting module.

Reports:
- Daily.
- Weekly.
- Monthly.
- Quarterly.
- Yearly.
- Custom date range.

Include:
- Total income.
- Total expenses.
- Net savings.
- Cash flow.
- Account-wise balances.
- Category-wise expenses.
- Income category breakdown.
- Loan given report.
- Loan taken report.
- Outstanding loan report.
- Person-wise balances.

Use clear charts and visually appealing reports.

Allow PDF and CSV exports.

Reports must be generated locally without requiring internet access.

# 13. SEARCH AND FILTER SYSTEM

Create global search across:
- Income.
- Expenses.
- Loans.
- People.
- Accounts.
- Categories.

Filters:
- Date range.
- Amount range.
- Transaction type.
- Account.
- Category.
- Person.

Search must be fast and work offline.

# 14. BACKUP AND RESTORE

Create a secure backup system.

Requirements:

- Export encrypted backup.
- Import encrypted backup.
- User-specific backup.
- Full application backup.
- Backup verification.
- Backup versioning.
- Restore confirmation.
- Database integrity verification after restore.

Use strong authenticated encryption such as AES-256-GCM for backup files.

Derive backup encryption keys securely from a user-provided backup password using Argon2id.

Never export plaintext financial records by default.

Allow users to choose an optional unencrypted CSV/PDF export for sharing individual reports, with a clear warning.

The app must not silently overwrite existing data during restoration.

Provide an option to create a backup before restoring.

# 15. PREMIUM UI/UX DESIGN

Design a modern, elegant, premium financial application.

Visual direction:

- Clean and minimal.
- Modern Material 3.
- Premium fintech aesthetic.
- Beautiful typography.
- Smooth micro-interactions.
- Subtle shadows.
- Rounded cards.
- Balanced whitespace.
- Beautiful charts.
- Professional icons.
- Consistent spacing.
- Responsive layouts.

Support:
- Light mode.
- Dark mode.
- System theme.
- Custom accent colors.

Suggested color direction:
- Deep navy.
- Emerald green.
- Soft neutral backgrounds.
- Carefully selected financial status colors.

Use bottom navigation:

1. Home.
2. Transactions.
3. Loans.
4. Reports.
5. Settings.

Add a floating quick-action button for:
- Add income.
- Add expense.
- Give loan.
- Take loan.
- Transfer money.

Create reusable UI components:
- Balance cards.
- Transaction tiles.
- Loan cards.
- Financial charts.
- Empty states.
- Loading skeletons.
- Confirmation dialogs.
- Form components.

Every screen must have proper loading, empty, success, and error states.

Avoid generic-looking template interfaces.

# 16. CURRENCY AND LOCALIZATION

Default currency: PKR (Pakistani Rupee).

Format:
Rs. 10,000

Support configurable currencies.

Support:
- English.
- Urdu.
- Right-to-left Urdu interface.
- Localized date and number formatting.

Do not hardcode currency symbols or date formats throughout the application.

Store monetary values as integer minor units wherever possible, not floating-point numbers.

Use exact decimal arithmetic for interest and financial calculations.

# 17. DATABASE DESIGN

Create a normalized database schema.

Required entities:

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

Every user-owned record must have proper ownership constraints.

Use:
- Foreign keys.
- Appropriate indexes.
- Unique constraints.
- Database transactions.
- Migration versioning.
- Referential integrity.

Design the database to prevent:
- Duplicate transactions.
- Invalid loan repayments.
- Negative balances where prohibited.
- Cross-user data leakage.
- Inconsistent financial totals.

Use a ledger-oriented design so financial events are traceable and balances can be reconstructed.

For corrections to posted financial events, use a safe correction or reversal mechanism rather than silently modifying historical financial facts.

# 18. PERFORMANCE AND RELIABILITY

The app must:
- Open quickly.
- Support large transaction histories.
- Use database pagination.
- Avoid unnecessary widget rebuilds.
- Perform heavy operations away from the UI thread where appropriate.
- Handle unexpected application termination safely.
- Use atomic database transactions.
- Handle database migration failures safely.
- Avoid data corruption.
- Work completely offline.

# 19. TESTING

Write comprehensive tests.

Unit tests:
- Income calculations.
- Expense calculations.
- Balance calculations.
- Loan calculations.
- Partial repayment calculations.
- Budget calculations.
- Currency calculations.
- Ownership validation.

Database tests:
- CRUD operations.
- Database encryption.
- Database migration.
- Transaction rollback.
- Backup and restore.
- User data isolation.

Widget tests:
- Dashboard.
- Login.
- Profile switching.
- Transaction forms.
- Loan forms.
- Reports.

Integration tests:
- Complete income workflow.
- Complete expense workflow.
- Loan given workflow.
- Loan taken workflow.
- Partial repayment workflow.
- Backup and restore workflow.
- Multi-user isolation workflow.

Test both Android and iOS.

# 20. DEVELOPMENT WORKFLOW

IMPORTANT: Do not attempt to generate the entire application in one giant code dump.

Work in carefully planned phases.

PHASE 1:
- Project architecture.
- Flutter project setup.
- Dependency setup.
- Design system.
- Database architecture.
- Security architecture.

PHASE 2:
- Authentication.
- Multi-user profiles.
- Database encryption.
- Profile isolation.

PHASE 3:
- Accounts management.
- Income management.
- Expense management.
- Transaction engine.

PHASE 4:
- People management.
- Loan given.
- Loan taken.
- Repayment system.

PHASE 5:
- Dashboard.
- Budgets.
- Reports.
- Analytics.

PHASE 6:
- Backup and restore.
- PDF/CSV exports.
- Reminders.
- Localization.

PHASE 7:
- Comprehensive testing.
- Security audit.
- Performance optimization.
- Android build.
- iOS build.

After each phase:
1. Explain what was implemented.
2. List files created or modified.
3. Run Flutter analyze.
4. Run relevant tests.
5. Fix all errors.
6. Update project documentation.
7. Confirm the phase is complete before moving to the next.

# 21. DEVELOPMENT RULES

- Never generate fake functionality.
- Never use hardcoded financial data in production screens.
- Never leave critical features as TODO.
- Never ignore compiler errors.
- Never ignore database errors.
- Never bypass encryption for convenience.
- Never mix data between users.
- Never put business logic inside UI widgets.
- Never create duplicate implementations.
- Follow Flutter and Dart best practices.
- Use meaningful names.
- Write maintainable code.
- Document complex security and financial logic.
- Do not claim a feature is secure unless it has been tested.
- Do not claim iOS support is complete without validating the iOS implementation.
- Keep the app functional after every development phase.

If a requirement is technically impossible or a package has limitations, explain the issue and propose a secure alternative before implementing it.

# 22. FINAL DELIVERY REQUIREMENTS

At the end, deliver:

1. Complete Flutter source code.
2. Working Android application.
3. iOS-ready application.
4. Encrypted local database.
5. Fully functional multi-user system.
6. Complete financial management modules.
7. Premium UI.
8. Secure backup and restore.
9. Unit and integration tests.
10. Database documentation.
11. Architecture documentation.
12. Security documentation.
13. README with installation instructions.
14. Android build instructions.
15. iOS build instructions.
16. A list of known limitations.

FINAL OBJECTIVE:

Build Hisab Pro into a premium, production-quality, offline personal accounting application that allows individuals to manage their entire financial life securely on their own device.

Prioritize data integrity, security, usability, and reliability over unnecessary complexity.

Start by inspecting the existing workspace. If it is empty, initialize the Flutter project. Then create the implementation plan and begin PHASE 1.

Do not stop after creating the plan. Continue implementing the application phase by phase.