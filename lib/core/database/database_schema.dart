/// Database schema definitions and DDL for Hisab Pro.
class DatabaseSchema {
  DatabaseSchema._();

  static const List<String> createTableStatements = [
    '''
    CREATE TABLE IF NOT EXISTS user_profiles (
      id TEXT PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      full_name TEXT NOT NULL,
      avatar_path TEXT,
      profile_pin_hash TEXT NOT NULL,
      salt TEXT NOT NULL,
      kdf_params TEXT NOT NULL,
      biometric_enabled INTEGER NOT NULL DEFAULT 0,
      lock_enabled INTEGER NOT NULL DEFAULT 1,
      inactivity_timeout_minutes INTEGER NOT NULL DEFAULT 5,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      last_login_at INTEGER
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS accounts (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      account_type TEXT NOT NULL,
      currency TEXT NOT NULL DEFAULT 'PKR',
      opening_balance_minor INTEGER NOT NULL DEFAULT 0,
      current_balance_minor INTEGER NOT NULL DEFAULT 0,
      is_archived INTEGER NOT NULL DEFAULT 0,
      notes TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(user_id, name)
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      color_hex TEXT,
      icon_key TEXT,
      is_default INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(user_id, name, type)
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS people (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      full_name TEXT NOT NULL,
      phone_number TEXT,
      address TEXT,
      notes TEXT,
      profile_image_path TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS attachments (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      file_name TEXT NOT NULL,
      storage_path TEXT NOT NULL,
      mime_type TEXT,
      file_size_bytes INTEGER NOT NULL,
      related_table TEXT,
      related_id TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
      category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
      person_id TEXT REFERENCES people(id) ON DELETE SET NULL,
      type TEXT NOT NULL CHECK(type IN ('income', 'expense', 'adjustment', 'reversal')),
      title TEXT NOT NULL,
      amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
      payment_method TEXT,
      transaction_date INTEGER NOT NULL,
      transaction_time INTEGER,
      notes TEXT,
      attachment_id TEXT REFERENCES attachments(id) ON DELETE SET NULL,
      status TEXT NOT NULL DEFAULT 'posted' CHECK(status IN ('posted', 'reversed', 'void')),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS transfers (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      from_account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
      to_account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
      amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
      transfer_date INTEGER NOT NULL,
      note TEXT,
      status TEXT NOT NULL DEFAULT 'posted' CHECK(status IN ('posted', 'reversed')),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      CHECK(from_account_id <> to_account_id)
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS loans (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      person_id TEXT NOT NULL REFERENCES people(id) ON DELETE RESTRICT,
      loan_type TEXT NOT NULL CHECK(loan_type IN ('loan_given', 'loan_taken')),
      amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
      interest_rate_percent REAL NOT NULL DEFAULT 0,
      loan_date INTEGER NOT NULL,
      due_date INTEGER,
      description TEXT,
      notes TEXT,
      account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
      status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'partial', 'overdue', 'paid', 'closed')),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS loan_repayments (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      loan_id TEXT NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
      repayment_date INTEGER NOT NULL,
      amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
      account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
      notes TEXT,
      payment_method TEXT,
      status TEXT NOT NULL DEFAULT 'posted' CHECK(status IN ('posted', 'reversed')),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS budgets (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      budget_month INTEGER NOT NULL,
      budget_year INTEGER NOT NULL,
      total_limit_minor INTEGER NOT NULL,
      currency TEXT NOT NULL DEFAULT 'PKR',
      notification_threshold_percent INTEGER DEFAULT 80,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(user_id, budget_month, budget_year)
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS budget_categories (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      budget_id TEXT NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
      category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
      limit_minor INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(budget_id, category_id)
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS reminders (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      reminder_type TEXT NOT NULL,
      related_table TEXT,
      related_id TEXT,
      title TEXT NOT NULL,
      reminder_date INTEGER NOT NULL,
      is_notified INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS app_settings (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      theme_mode TEXT NOT NULL DEFAULT 'system',
      accent_color TEXT,
      locale TEXT NOT NULL DEFAULT 'en',
      default_currency TEXT NOT NULL DEFAULT 'PKR',
      lock_timeout_minutes INTEGER NOT NULL DEFAULT 5,
      biometric_enabled INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(user_id)
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS audit_events (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      event_type TEXT NOT NULL,
      event_category TEXT NOT NULL,
      entity_type TEXT,
      entity_id TEXT,
      metadata_json TEXT,
      created_at INTEGER NOT NULL
    );
    ''',
  ];

  static const List<String> createIndexStatements = [
    'CREATE INDEX IF NOT EXISTS idx_accounts_user ON accounts(user_id);',
    'CREATE INDEX IF NOT EXISTS idx_categories_user ON categories(user_id, type);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON transactions(user_id, transaction_date DESC);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(account_id);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);',
    'CREATE INDEX IF NOT EXISTS idx_transfers_user ON transfers(user_id, transfer_date DESC);',
    'CREATE INDEX IF NOT EXISTS idx_people_user ON people(user_id);',
    'CREATE INDEX IF NOT EXISTS idx_loans_user_status ON loans(user_id, status);',
    'CREATE INDEX IF NOT EXISTS idx_loans_person ON loans(person_id);',
    'CREATE INDEX IF NOT EXISTS idx_loan_repayments_loan ON loan_repayments(loan_id);',
    'CREATE INDEX IF NOT EXISTS idx_budgets_user_date ON budgets(user_id, budget_year, budget_month);',
    'CREATE INDEX IF NOT EXISTS idx_reminders_user_date ON reminders(user_id, reminder_date);',
    'CREATE INDEX IF NOT EXISTS idx_audit_events_user ON audit_events(user_id, created_at DESC);',
  ];
}

