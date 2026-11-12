# Hisab Pro Database Schema Design

## 1. Database philosophy

The database is the foundation of the application. It must be:

- secure
- normalized
- multi-user aware
- ledger-oriented
- migration-safe
- auditable
- consistent under concurrent writes

The design must support long-term personal finance tracking without relying on a remote backend. In practice, that means strong ownership constraints, immutable financial facts, consistent totals, and explicit correction workflows.

---

## 2. Core design principles

### 2.1 Ledger-first model

The app should not treat balances as a simple scalar stored in a single table. Instead, it should derive totals from immutable event records such as:

- incomes
- expenses
- transfers
- loan repayments
- loan principal events

This allows a user to reconstruct total balances and audit changes accurately.

### 2.2 Money precision

Monetary values must be stored as integer minor units (for example, PKR in paise or smallest unit) instead of floating-point values. This eliminates rounding errors and prevents data corruption in interest and loan calculations.

### 2.3 User ownership

Every table must carry `user_id` ownership. No table should allow cross-user reads or writes without validation. Repositories and database queries must validate ownership even if the UI logic is bypassed.

### 2.4 Immutable financial history

Instead of editing historical financial facts silently, the system should record corrections through reversal entries or status changes where necessary.

---

## 3. Required entities and relationships

### 3.1 user_profiles

Represents a local user profile on the device.

Fields:

- id: TEXT PRIMARY KEY
- username: TEXT NOT NULL UNIQUE
- full_name: TEXT NOT NULL
- avatar_path: TEXT NULL
- profile_pin_hash: TEXT NOT NULL
- salt: TEXT NOT NULL
- kdf_params: TEXT NOT NULL
- biometric_enabled: INTEGER NOT NULL DEFAULT 0
- lock_enabled: INTEGER NOT NULL DEFAULT 1
- inactivity_timeout_minutes: INTEGER NOT NULL DEFAULT 5
- is_active: INTEGER NOT NULL DEFAULT 1
- is_deleted: INTEGER NOT NULL DEFAULT 0
- created_at: INTEGER NOT NULL
- updated_at: INTEGER NOT NULL
- last_login_at: INTEGER NULL

Notes:

- This table should not hold plaintext financial secrets.
- The user profile should have its own database key and access path.

### 3.2 accounts

Financial accounts for the user.

Fields:

- id: TEXT PRIMARY KEY
- user_id: TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE
- name: TEXT NOT NULL
- account_type: TEXT NOT NULL
- currency: TEXT NOT NULL DEFAULT 'PKR'
- opening_balance_minor: INTEGER NOT NULL DEFAULT 0
- current_balance_minor: INTEGER NOT NULL DEFAULT 0
- is_archived: INTEGER NOT NULL DEFAULT 0
- notes: TEXT NULL
- created_at: INTEGER NOT NULL
- updated_at: INTEGER NOT NULL

Constraints:

- UNIQUE(user_id, name)
- CHECK(account_type IN (...))

Notes:

- `current_balance_minor` should normally be derived or validated against ledger entries.
- opening balance should be treated as a ledger initialization event or a first transaction.

### 3.3 categories

Reusable categories for income, expense, and other financial records.

Fields:

- id: TEXT PRIMARY KEY
- user_id: TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE
- name: TEXT NOT NULL
- type: TEXT NOT NULL  -- income, expense, transfer, loan, custom
- color_hex: TEXT NULL
- icon_key: TEXT NULL
- is_default: INTEGER NOT NULL DEFAULT 0
- is_active: INTEGER NOT NULL DEFAULT 1
- created_at: INTEGER NOT NULL
- updated_at: INTEGER NOT NULL

Constraints:

- UNIQUE(user_id, name, type)

### 3.4 transactions

Core ledger table for every income or expense event.

Fields:

- id: TEXT PRIMARY KEY
- user_id: TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE
- account_id: TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT
- category_id: TEXT NULL REFERENCES categories(id) ON DELETE SET NULL
- person_id: TEXT NULL REFERENCES people(id) ON DELETE SET NULL
- type: TEXT NOT NULL  -- income, expense, adjustment, reversal
- title: TEXT NOT NULL
- amount_minor: INTEGER NOT NULL
- payment_method: TEXT NULL
- transaction_date: INTEGER NOT NULL
- transaction_time: INTEGER NULL
- notes: TEXT NULL
- attachment_id: TEXT NULL REFERENCES attachments(id) ON DELETE SET NULL
- status: TEXT NOT NULL DEFAULT 'posted'
- created_at: INTEGER NOT NULL
- updated_at: INTEGER NOT NULL

Constraints:

- CHECK(amount_minor >= 0)
- CHECK(type IN ('income', 'expense', 'adjustment', 'reversal'))
- CHECK(status IN ('posted', 'reversed', 'void'))

Notes:

- This is the main fact table for incomes and expenses.
- Reversals should not mutate historical financial facts silently.

### 3.5 transfers

Represents movement of money between two internal accounts.

Fields:

- id: TEXT PRIMARY KEY
- user_id: TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE
- from_account_id: TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT
- to_account_id: TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT
- amount_minor: INTEGER NOT NULL
- transfer_date: INTEGER NOT NULL
- note: TEXT NULL
- status: TEXT NOT NULL DEFAULT 'posted'
- created_at: INTEGER NOT NULL
- updated_at: INTEGER NOT NULL

Constraints:

- CHECK(amount_minor > 0)
- CHECK(from_account_id <> to_account_id)
- CHECK(status IN ('posted', 'reversed'))

Notes:

- A transfer should be represented as a paired debit and credit event or a dedicated linked journal flow.
- It must never be treated as income or expense.

### 3.6 people

Represents individuals or businesses associated with loans, income, or expense activity.

Fields:

- id: TEXT PRIMARY KEY
- user_id: TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE
- full_name: TEXT NOT NULL
- phone_number: TEXT NULL
- address: TEXT NULL
- notes: TEXT NULL
- profile_image_path: TEXT NULL
- created_at: INTEGER NOT NULL
- updated_at: INTEGER NOT NULL

Constraints:

- UNIQUE(user_id, phone_number) when phone_number is not null

### 3.7 loans

Main loan record holding principal details.

Fields:

- id: TEXT PRIMARY KEY
- user_id: TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE
- person_id: TEXT NOT NULL REFERENCES people(id) ON DELETE RESTRICT
- loan_type: TEXT NOT NULL  -- loan_given, loan_taken
- amount_minor: INTEGER NOT NULL
- interest_rate_percent: REAL NOT NULL DEFAULT 0
- loan_date: INTEGER NOT NULL
- due_date: INTEGER NULL
- description: TEXT NULL
- notes: TEXT NULL
- account_id: TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT
- status: TEXT NOT NULL DEFAULT 'active'  -- active, partial, paid, overdue, closed
- created_at: INTEGER NOT NULL
- updated_at: INTEGER NOT NULL

Constraints:

- CHECK(amount_minor > 0)
- CHECK(loan_type IN ('loan_given', 'loan_taken'))
- CHECK(status IN ('active', 'partial', 'overdue', 'paid', 'closed'))

Notes:

- The original principal amount must stay intact.
- Repaid amounts must be stored as linked repayment events, not by overwriting the principal.

### 3.8 loan_repayments

Repayment history for each loan. This is the critical linkage table.

Fields:

- id: TEXT PRIMARY KEY
- user_id: TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE
- loan_id: TEXT NOT NULL REFERENCES loans(id) ON DELETE CASCADE
- repayment_date: INTEGER NOT NULL
- amount_minor: INTEGER NOT NULL
- account_id: TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT
- notes: TEXT NULL
- payment_method: TEXT NULL
- status: TEXT NOT NULL DEFAULT 'posted'
- created_at: INTEGER NOT NULL
- updated_at: INTEGER NOT NULL

Constraints:

- CHECK(amount_minor > 0)
- CHECK(status IN ('posted', 'reversed'))

Notes:

- Every repayment is a separate immutable financial event.
- The database must enforce that total repayments do not exceed the principal unless explicitly allowed by policy.

### 3.9 budgets

Monthly total budget record.

Fields:

- id: TEXT PRIMARY KEY
- user_id: TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE
- name: TEXT NOT NULL
- budget_month: INTEGER NOT NULL
- budget_year: INTEGER NOT NULL
- total_limit_minor: INTEGER NOT NULL
- currency: TEXT NOT NULL DEFAULT 'PKR'
- notification_threshold_percent: INTEGER DEFAULT 80
- created_at: INTEGER NOT NULL
- updated_at: INTEGER NOT NULL

Constraints:

- UNIQUE(user_id, budget_month, budget_year)

### 3.10 budget_categories

Category-specific monthly budget allocations.

Fields:

- id: TEXT PRIMARY KEY
- user_id: TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE
- budget_id: TEXT NOT NULL REFERENCES budgets(id) ON DELETE CASCADE
- category_id: TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT
- limit_minor: INTEGER NOT NULL
- created_at: INTEGER NOT NULL
- updated_at: INTEGER NOT NULL

Constraints:

- UNIQUE(budget_id, category_id)

### 3.11 attachments

Metadata and references to user attachments.

Fields:

- id: TEXT PRIMARY KEY
- user_id: TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE
- file_name: TEXT NOT NULL
- storage_path: TEXT NOT NULL
- mime_type: TEXT NULL
- file_size_bytes: INTEGER NOT NULL
- related_table: TEXT NULL
- related_id: TEXT NULL
- created_at: INTEGER NOT NULL
- updated_at: INTEGER NOT NULL

Notes:

- Keep actual files in app storage or a trusted local directory.
- Attachment metadata must not leak across users.

### 3.12 reminders

Local reminder records for due loans, budget thresholds, or recurring financial events.

Fields:

- id: TEXT PRIMARY KEY
- user_id: TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE
- reminder_type: TEXT NOT NULL  -- loan_due, budget_threshold, custom
- related_table: TEXT NULL
- related_id: TEXT NULL
- title: TEXT NOT NULL
- reminder_date: INTEGER NOT NULL
- is_notified: INTEGER NOT NULL DEFAULT 0
- created_at: INTEGER NOT NULL
- updated_at: INTEGER NOT NULL

### 3.13 app_settings

User-specific application preferences.

Fields:

- id: TEXT PRIMARY KEY
- user_id: TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE
- theme_mode: TEXT NOT NULL DEFAULT 'system'
- accent_color: TEXT NULL
- locale: TEXT NOT NULL DEFAULT 'en'
- default_currency: TEXT NOT NULL DEFAULT 'PKR'
- lock_timeout_minutes: INTEGER NOT NULL DEFAULT 5
- biometric_enabled: INTEGER NOT NULL DEFAULT 1
- created_at: INTEGER NOT NULL
- updated_at: INTEGER NOT NULL

Constraints:

- UNIQUE(user_id)

### 3.14 audit_events

Security and data-change tracking for operational oversight.

Fields:

- id: TEXT PRIMARY KEY
- user_id: TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE
- event_type: TEXT NOT NULL
- event_category: TEXT NOT NULL
- entity_type: TEXT NULL
- entity_id: TEXT NULL
- metadata_json: TEXT NULL
- created_at: INTEGER NOT NULL

Notes:

- This is important for security audits and troubleshooting.
- Avoid storing sensitive raw values in plaintext; keep sanitized summaries.

---

## 4. Relationship summary

- user_profiles -> accounts, categories, transactions, people, loans, budgets, reminders, app_settings, attachments, audit_events
- accounts -> transactions, transfers, loan_repayments
- categories -> transactions, budget_categories
- people -> loans, transactions
- loans -> loan_repayments
- budgets -> budget_categories
- attachments -> transactions and other records by relation metadata

This forms a connected ledger network with strong ownership boundaries.

---

## 5. Important indexes

Recommended indexes:

- transactions(user_id, transaction_date)
- transactions(user_id, account_id, type)
- transactions(user_id, category_id)
- transfers(user_id, transfer_date)
- people(user_id, full_name)
- loans(user_id, loan_type, status)
- loan_repayments(user_id, loan_id, repayment_date)
- budgets(user_id, budget_year, budget_month)
- budget_categories(budget_id, category_id)
- audit_events(user_id, created_at)
- reminders(user_id, reminder_date)

---

## 6. Constraints and validation rules

The schema should enforce:

- `user_id` foreign key on every user-owned entity
- `UNIQUE` names where duplicates are not allowed
- no negative monetary values on most tables
- valid statuses and types
- transfer must not be same account to same account
- loan repayment amount must be positive
- category type must match transaction type where applicable
- restore operations must check schema version and backup integrity before apply

---

## 7. Migration and integrity rules

The database must support migration versioning with:

- explicit schema versions
- safe migration ordering
- pre-checks before destructive changes
- rollback strategy for transaction failure
- after migration, integrity validation query

Database integrity must be checked before app usage and after restore.

---

## 8. Recommended additional support tables (optional but useful)

These are not part of the required core spec but are practical for production-grade reliability:

- schema_migrations
- backup_records
- database_metadata
- account_balance_snapshots
- report_cache
- security_events

These can help with version control and restore verification, but they should be introduced only when needed and after the core schema is stable.

---

## 9. Final schema design recommendation

The best architecture for this project is:

- one encrypted database per user profile or a single database with strict tenancy and profile-specific encryption keys
- each table carries `user_id`
- ledger tables are the source of truth
- derived balances are checks rather than primary data
- loan repayments remain separate immutable records
- backup and restore verify schema versions before applying

This will satisfy the specification while preserving data integrity, security, and maintainability.
