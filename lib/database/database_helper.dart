import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import '../utils/date_converter.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static bool _initialized = false;

  static void init() {
    if (!_initialized) {
      print('🔄 Initializing sqflite FFI...');
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _initialized = true;
      print('✅ sqflite FFI initialized!');
    }
  }

  Future<void> _ensureSupplierLoanTables(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_loans(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL,
          raw_material_id INTEGER,
          invoice_number TEXT,
          supplier_name TEXT,
          supplier_company TEXT,
          total_amount REAL NOT NULL,
          paid_amount REAL NOT NULL DEFAULT 0,
          remaining_amount REAL NOT NULL DEFAULT 0,
          loan_type TEXT,
          currency TEXT,
          due_date TEXT,
          date TEXT,
          date_en TEXT,
          description TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
          FOREIGN KEY (raw_material_id) REFERENCES raw_materials (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_loan_payments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          loan_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          date TEXT,
          date_en TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (loan_id) REFERENCES supplier_loans (id)
        )
      ''');

      print('✅ Supplier loans tables created successfully!');
    } catch (e) {
      print('❌ Error ensuring supplier loan tables: $e');
      rethrow;
    }
  }

  Future<void> _ensureSellLoanTables(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sell_loans(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_invoice_id INTEGER,
          invoice_number TEXT,
          customer_name TEXT,
          customer_company TEXT,
          total_amount REAL NOT NULL,
          paid_amount REAL NOT NULL DEFAULT 0,
          remaining_amount REAL NOT NULL DEFAULT 0,
          loan_type TEXT,
          currency TEXT,
          due_date TEXT,
          date TEXT,
          date_en TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sell_loan_payments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          loan_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          date TEXT,
          date_en TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (loan_id) REFERENCES sell_loans (id)
        )
      ''');

      print('✅ Sell loans tables created successfully!');
    } catch (e) {
      print('❌ Error ensuring sell loan tables: $e');
      rethrow;
    }
  }

  Future<void> _ensureRawMaterialColumns(Database db) async {
    try {
      final rawMaterialCols = await db.rawQuery("PRAGMA table_info('raw_materials')");
      final rawMaterialColumnNames = rawMaterialCols
          .map((c) => c['name']?.toString())
          .whereType<String>()
          .toSet();
      final expectedColumns = <String, String>{
        'supplier_id': 'INTEGER',
        'location': 'TEXT',
        'material_type': 'TEXT',
        'thickness': 'TEXT',
        'net_weight': 'TEXT',
        'gross_weight': 'TEXT',
        'date': 'TEXT',
        'date_en': 'TEXT',
        'unit': 'TEXT',
        'unit_price': 'TEXT',
        'product': 'TEXT',
        'commission': 'TEXT',
        'transfer_cost': 'TEXT',
        'miscellaneous': 'TEXT',
        'ghurfedari': 'TEXT',
        'barchalani': 'TEXT',
        'purchase_type': 'TEXT',
        'seller_payment': 'TEXT',
        'seller_payment_method': 'TEXT',
        'seller_paid_amount': 'TEXT',
        'currency': 'TEXT',
        'exchange_rate': 'REAL',
        'final_price': 'TEXT',
      };

      for (final entry in expectedColumns.entries) {
        if (!rawMaterialColumnNames.contains(entry.key)) {
          try {
            await db.execute('ALTER TABLE raw_materials ADD COLUMN ${entry.key} ${entry.value}');
            print('✅ Added missing raw_materials column ${entry.key}');
          } catch (e) {
            print('⚠️ Error adding raw_materials column ${entry.key}: $e');
          }
        }
      }
    } catch (e) {
      print('⚠️ Error ensuring raw_materials columns: $e');
    }
  }

  Future<void> _ensureSalesInvoiceProductRelation(Database db) async {
    try {
      final columns = await db.rawQuery("PRAGMA table_info('sales_invoices')");
      final columnNames = columns.map((c) => c['name']?.toString()).whereType<String>().toSet();
      
      if (!columnNames.contains('produced_product_id')) {
        await db.execute('ALTER TABLE sales_invoices ADD COLUMN produced_product_id INTEGER');
        print('✅ Added produced_product_id column to sales_invoices');
      }
    } catch (e) {
      print('⚠️ Error adding produced_product_id: $e');
    }
  }

  Future<Database> get database async {
    try {
      init();
      if (_database != null) return _database!;
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      print('❌ Database initialization error: $e');
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = join(directory.path, 'victor_pipe.db');
      
      print('✅ Database path: $path');
      
      return await openDatabase(
        path,
        version: 28,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          print('✅ Database opened successfully!');
          await _ensureProducedProductsTable(db);
          await _ensureCapitalTables(db);
          await _ensureSarafiTables(db);
          await _ensureCustomerCompanyTables(db);
          await _ensureSalesInvoiceTable(db);
          await _ensureServiceInvoicesTable(db);
          await _ensureSupplierLoanTables(db);
          await _ensureSellLoanTables(db);
          await _ensureRawMaterialColumns(db);
          await _ensureDailyExpensesTable(db);
          await _ensureWasteMaterialsTable(db);
          await _ensureSalesInvoiceProductRelation(db);
          await db.execute('PRAGMA busy_timeout = 5000');
          await db.execute('PRAGMA journal_mode = WAL');
        },
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA busy_timeout = 5000');
        },
      );
    } catch (e) {
      print('❌ Error with primary path: $e');
      return await _initDatabaseFallback();
    }
  }

  Future<Database> _initDatabaseFallback() async {
    try {
      final directory = await getTemporaryDirectory();
      final path = join(directory.path, 'victor_pipe.db');
      
      print('✅ Using fallback database path: $path');
      
      return await openDatabase(
        path,
        version: 28,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          print('✅ Database opened successfully (fallback)!');
          await _ensureProducedProductsTable(db);
          await _ensureCapitalTables(db);
          await _ensureSarafiTables(db);
          await _ensureCustomerCompanyTables(db);
          await _ensureSalesInvoiceTable(db);
          await _ensureServiceInvoicesTable(db);
          await _ensureSupplierLoanTables(db);
          await _ensureSellLoanTables(db);
          await _ensureRawMaterialColumns(db);
          await _ensureDailyExpensesTable(db);
          await _ensureWasteMaterialsTable(db);
          await _ensureSalesInvoiceProductRelation(db);
          await db.execute('PRAGMA busy_timeout = 5000');
          await db.execute('PRAGMA journal_mode = WAL');
        },
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA busy_timeout = 5000');
        },
      );
    } catch (e) {
      print('❌ Error with fallback path: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      print('🔄 Creating database tables...');
      await _createTables(db);
      await _insertSampleData(db);
      print('✅ Database created successfully!');
    } catch (e) {
      print('❌ Error creating database: $e');
      rethrow;
    }
  }

 Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  try {
    print('🔄 Upgrading database from version $oldVersion to $newVersion...');
    
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE suppliers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          email TEXT,
          address TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      print('✅ Suppliers table added!');
      
      await db.insert('suppliers', {
        'name': 'تامین پلیمر تهران',
        'phone': '021 1234 5678',
        'email': 'info@taminpolimer.com',
        'address': 'تهران، خیابان آزادی، پلاک ۱۲۳',
      });
      print('✅ Sample supplier added!');
    }
    
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE raw_materials(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER,
          name TEXT NOT NULL,
          location TEXT,
          material_type TEXT,
          thickness TEXT,
          net_weight TEXT,
          gross_weight TEXT,
          date TEXT,
          date_en TEXT,
          unit TEXT,
          unit_price TEXT,
          product TEXT,
          commission TEXT,
          transfer_cost TEXT,
          miscellaneous TEXT,
          ghurfedari TEXT,
          barchalani TEXT,
          purchase_type TEXT,
          seller_payment TEXT,
          seller_payment_method TEXT,
          seller_paid_amount TEXT,
          currency TEXT,
          exchange_rate REAL,
          final_price TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
        )
      ''');
      print('✅ Raw materials table added!');
    }

    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN location TEXT');
      } catch (e) { print('⚠️ location: $e'); }
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN material_type TEXT');
      } catch (e) { print('⚠️ material_type: $e'); }
      print('✅ Version 4 upgrade done!');
    }

    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN date TEXT');
      } catch (e) { print('⚠️ date: $e'); }
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN unit TEXT');
      } catch (e) { print('⚠️ unit: $e'); }
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN unit_price TEXT');
      } catch (e) { print('⚠️ unit_price: $e'); }
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN product TEXT');
      } catch (e) { print('⚠️ product: $e'); }
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN commission TEXT');
      } catch (e) { print('⚠️ commission: $e'); }
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN transfer_cost TEXT');
      } catch (e) { print('⚠️ transfer_cost: $e'); }
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN miscellaneous TEXT');
      } catch (e) { print('⚠️ miscellaneous: $e'); }
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN final_price TEXT');
      } catch (e) { print('⚠️ final_price: $e'); }
      print('✅ Version 5 upgrade done!');
    }

    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN ghurfedari TEXT');
      } catch (e) { print('⚠️ ghurfedari: $e'); }
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN barchalani TEXT');
      } catch (e) { print('⚠️ barchalani: $e'); }
      print('✅ Version 6 upgrade done!');
    }

    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN profile_pic TEXT');
        print('✅ Added profile_pic column to users table');
      } catch (e) {
        print('⚠️ Error adding profile_pic: $e');
      }
      print('✅ Database upgraded to version 9!');
    }

    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN purchase_type TEXT');
        print('✅ Added purchase_type column to raw_materials table');
      } catch (e) {
        print('⚠️ Error adding purchase_type: $e');
      }
      print('✅ Database upgraded to version 10!');
    }

    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN date_en TEXT');
        print('✅ Added date_en column to raw_materials table');
      } catch (e) {
        print('⚠️ Error adding date_en: $e');
      }
      print('✅ Database upgraded to version 11!');
    }

    if (oldVersion < 24) {
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN seller_payment TEXT');
        await db.execute('ALTER TABLE raw_materials ADD COLUMN seller_payment_method TEXT');
        await db.execute('ALTER TABLE raw_materials ADD COLUMN seller_paid_amount TEXT');
        print('✅ Added seller payment columns to raw_materials table');
      } catch (e) {
        print('⚠️ Error adding seller payment columns: $e');
      }
      print('✅ Database upgraded to version 24!');
    }

    if (oldVersion < 25) {
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN currency TEXT');
      } catch (e) {
        print('⚠️ Error adding currency column to raw_materials: $e');
      }
      try {
        await db.execute('ALTER TABLE raw_materials ADD COLUMN exchange_rate REAL');
      } catch (e) {
        print('⚠️ Error adding exchange_rate column to raw_materials: $e');
      }
      print('✅ Database upgraded to version 25!');
    }

    if (oldVersion < 26) {
      try {
        await _ensureSalesInvoiceProductRelation(db);
        print('✅ Added produced_product_id relationship to sales_invoices');
      } catch (e) {
        print('⚠️ Error adding produced_product_id: $e');
      }
      print('✅ Database upgraded to version 26!');
    }

    if (oldVersion < 27) {
      try {
        await _ensureSupplierLoanTables(db);
        print('✅ Added supplier_loans table');
      } catch (e) {
        print('⚠️ Error adding supplier_loans table: $e');
      }
      print('✅ Database upgraded to version 27!');
    }

    if (oldVersion < 28) {
      try {
        print('🔄 Fixing service_invoices table for version 28...');
        final columns = await db.rawQuery("PRAGMA table_info('service_invoices')");
        final columnNames = columns.map((c) => c['name']?.toString()).whereType<String>().toSet();
        
        if (!columnNames.contains('invoice_number')) {
          await db.execute('ALTER TABLE service_invoices ADD COLUMN invoice_number TEXT');
          print('✅ Added invoice_number column to service_invoices');
          await db.execute('UPDATE service_invoices SET invoice_number = "SERV" || substr("00000" || id, -5, 5) WHERE invoice_number IS NULL');
          print('✅ Updated existing service invoices with invoice numbers');
        }
        print('⚠️ Note: To make invoice_number NOT NULL UNIQUE, recreate the table or ensure all rows have values');
      } catch (e) {
        print('⚠️ Error fixing service_invoices table: $e');
      }
      print('✅ Database upgraded to version 28!');
    }

    // ADD DRIVER_NAME AND NUMBER_PLATE COLUMNS - KEEP VERSION 28
    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN driver_name TEXT');
      print('✅ Added driver_name column to sales_invoices');
    } catch (e) {
      print('⚠️ driver_name column already exists: $e');
    }

    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN number_plate TEXT');
      print('✅ Added number_plate column to sales_invoices');
    } catch (e) {
      print('⚠️ number_plate column already exists: $e');
    }

    if (oldVersion < 13) {
      try {
        await _ensureProducedProductsTable(db);
        print('✅ Ensured produced_products table exists');
      } catch (e) {
        print('⚠️ Error ensuring produced_products table: $e');
      }
      print('✅ Database upgraded to version 13!');
    }

    if (oldVersion < 14) {
      try {
        await _ensureCapitalTables(db);
        print('✅ Ensured capital tables exist');
      } catch (e) {
        print('⚠️ Error ensuring capital tables: $e');
      }
      print('✅ Database upgraded to version 14!');
    }

    if (oldVersion < 15) {
      try {
        await _ensureCustomerCompanyTables(db);
        print('✅ Ensured customer/company tables exist');
      } catch (e) {
        print('⚠️ Error ensuring customer/company tables: $e');
      }
      print('✅ Database upgraded to version 15!');
    }

    if (oldVersion < 16) {
      try {
        await _ensureSalesInvoiceTable(db);
        print('✅ Ensured sales invoices table exists');
      } catch (e) {
        print('⚠️ Error ensuring sales invoices table: $e');
      }
      print('✅ Database upgraded to version 16!');
    }

    if (oldVersion < 17) {
      try {
        await db.execute('ALTER TABLE sales_invoices ADD COLUMN loading_time TEXT');
        print('✅ Added loading_time column to sales_invoices table');
      } catch (e) {
        print('⚠️ Error adding loading_time column: $e');
      }
      try {
        await db.execute('ALTER TABLE sales_invoices ADD COLUMN loading_time_en TEXT');
        print('✅ Added loading_time_en column to sales_invoices table');
      } catch (e) {
        print('⚠️ Error adding loading_time_en column: $e');
      }
      try {
        await db.execute('ALTER TABLE sales_invoices ADD COLUMN price_rate REAL');
      } catch (e) {
        print('⚠️ Error adding price_rate column (may already exist): $e');
      }
      print('✅ Database upgraded to version 17!');
    }

    if (oldVersion < 18) {
      try {
        print('🔄 Migrating daily_expenses to remove bill_number and registration_number...');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS daily_expenses_new(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_number TEXT UNIQUE,
            date TEXT,
            date_en TEXT,
            category TEXT,
            description TEXT,
            price REAL,
            currency TEXT,
            exchange_rate REAL,
            usd_equivalent REAL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        await db.execute('''
          INSERT INTO daily_expenses_new (id, invoice_number, date, date_en, category, description, price, currency, exchange_rate, usd_equivalent, created_at)
          SELECT id, invoice_number, date, date_en, category, description, price, currency, exchange_rate, usd_equivalent, created_at FROM daily_expenses
        ''');
        await db.execute('DROP TABLE IF EXISTS daily_expenses');
        await db.execute('ALTER TABLE daily_expenses_new RENAME TO daily_expenses');
        print('✅ Migration to version 18 completed!');
      } catch (e) {
        print('⚠️ Migration to version 18 failed: $e');
      }
    }

    if (oldVersion < 19) {
      try {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN account_id INTEGER');
        await db.execute("UPDATE sarafi_transactions SET account_id = 1 WHERE account_id IS NULL");
        print('✅ Added account_id column to sarafi_transactions');
      } catch (e) {
        print('⚠️ Error adding account_id to sarafi_transactions: $e');
      }
    }

    if (oldVersion < 20) {
      try {
        print('🔄 Migrating sarafi_transactions: renaming afn_equivalent to amount_afn...');
        
        final columns = await db.rawQuery('PRAGMA table_info(sarafi_transactions)');
        final columnNames = columns.map((row) => row['name']?.toString()).toSet();
        
        if (columnNames.contains('afn_equivalent') && !columnNames.contains('amount_afn')) {
          await db.execute('ALTER TABLE sarafi_transactions RENAME TO sarafi_transactions_old');
          
          await db.execute('''
            CREATE TABLE sarafi_transactions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              account_id INTEGER,
              transaction_type TEXT NOT NULL,
              amount_usd REAL NOT NULL,
              exchange_rate REAL NOT NULL DEFAULT 1,
              amount_afn REAL NOT NULL DEFAULT 0,
              balance_after REAL NOT NULL DEFAULT 0,
              source_name TEXT,
              source_account TEXT,
              source_email TEXT,
              source_phone TEXT,
              date TEXT,
              date_en TEXT,
              address TEXT,
              note TEXT,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (account_id) REFERENCES sarafi_accounts (id)
            )
          ''');
          
          await db.execute('''
            INSERT INTO sarafi_transactions 
              (id, account_id, transaction_type, amount_usd, exchange_rate, 
               source_name, source_account, source_email, source_phone, 
               date, date_en, address, note, created_at, amount_afn, balance_after)
            SELECT 
              id, account_id, transaction_type, amount_usd, exchange_rate,
              source_name, source_account, source_email, source_phone,
              date, date_en, address, note, created_at, afn_equivalent, 0
            FROM sarafi_transactions_old
          ''');
          
          await db.execute('DROP TABLE sarafi_transactions_old');
          print('✅ Successfully renamed afn_equivalent to amount_afn');
        } else if (!columnNames.contains('amount_afn')) {
          await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN amount_afn REAL NOT NULL DEFAULT 0');
          print('✅ Added amount_afn column');
        }
      } catch (e) {
        print('⚠️ Error migrating amount_afn column: $e');
      }
    }

    if (oldVersion < 22) {
      try {
        await _ensureWasteMaterialsTable(db);
        print('✅ Ensured waste_material_losses table exists');
      } catch (e) {
        print('⚠️ Error ensuring waste_material_losses table: $e');
      }
      print('✅ Database upgraded to version 22!');
    }

    if (oldVersion < 21) {
      try {
        print('🔄 Migrating sarafi_transactions: adding balance_after...');
        
        final columns = await db.rawQuery('PRAGMA table_info(sarafi_transactions)');
        final columnNames = columns.map((row) => row['name']?.toString()).toSet();
        
        if (!columnNames.contains('balance_after')) {
          await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN balance_after REAL NOT NULL DEFAULT 0');
          print('✅ Added balance_after column');
        } else {
          print('✅ balance_after column already exists');
        }
      } catch (e) {
        print('⚠️ Error adding balance_after column: $e');
      }
    }
    
    print('✅ Database upgraded successfully!');
  } catch (e) {
    print('❌ Error upgrading database: $e');
    rethrow;
  }
}

  // ============ PRODUCED PRODUCTS TABLE (SINGLE DEFINITION) ============
 Future<void> _ensureProducedProductsTable(Database db) async {
  try {
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='produced_products'");
    
    if (tables.isEmpty) {
      // Create table WITHOUT product_name (or with it as nullable)
      await db.execute('''
        CREATE TABLE produced_products(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_name TEXT,
          production_type TEXT,
          size TEXT,
          thickness TEXT,
          length TEXT,
          raw_count INTEGER,
          raw_weight REAL,
          total_weight REAL,
          unit TEXT,
          production_date TEXT,
          production_date_en TEXT,
          status TEXT,
          description TEXT,
          remaining_stock REAL DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      print('✅ produced_products table created with all fields!');
    } else {
      // Table exists - check columns
      final columns = await db.rawQuery("PRAGMA table_info('produced_products')");
      final columnNames = columns.map((c) => c['name']?.toString()).whereType<String>().toSet();
      
      print('📋 Existing columns: $columnNames');
      
      // Check if product_name is NOT NULL and remove the constraint
      final productNameCol = columns.firstWhere(
        (col) => col['name']?.toString() == 'product_name',
        orElse: () => {},
      );
      
      if (productNameCol.isNotEmpty) {
        final notNull = productNameCol['notnull'] ?? 0;
        if (notNull == 1) {
          // product_name is NOT NULL - we need to make it nullable
          // SQLite doesn't support dropping NOT NULL directly, so we need to recreate the table
          print('⚠️ product_name has NOT NULL constraint - migrating to make it nullable...');
          
          // Create a new table without the NOT NULL constraint
          await db.execute('''
            CREATE TABLE produced_products_new(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              product_name TEXT,
              production_type TEXT,
              size TEXT,
              thickness TEXT,
              length TEXT,
              raw_count INTEGER,
              raw_weight REAL,
              total_weight REAL,
              unit TEXT,
              production_date TEXT,
              production_date_en TEXT,
              status TEXT,
              description TEXT,
              remaining_stock REAL DEFAULT 0,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
          ''');
          
          // Copy data from old table to new table
          await db.execute('''
            INSERT INTO produced_products_new (
              id, product_name, production_type, size, thickness, length,
              raw_count, raw_weight, total_weight, unit,
              production_date, production_date_en, status, description,
              remaining_stock, created_at
            )
            SELECT 
              id, product_name, production_type, size, thickness, length,
              raw_count, raw_weight, total_weight, unit,
              production_date, production_date_en, status, description,
              remaining_stock, created_at
            FROM produced_products
          ''');
          
          // Drop old table and rename new one
          await db.execute('DROP TABLE produced_products');
          await db.execute('ALTER TABLE produced_products_new RENAME TO produced_products');
          
          print('✅ product_name NOT NULL constraint removed successfully!');
        }
      }
      
      // Add missing columns one by one
      final requiredColumns = {
        'size': 'TEXT',
        'raw_count': 'INTEGER',
        'raw_weight': 'REAL',
        'total_weight': 'REAL',
        'production_date_en': 'TEXT',
      };
      
      for (final entry in requiredColumns.entries) {
        if (!columnNames.contains(entry.key)) {
          try {
            await db.execute('ALTER TABLE produced_products ADD COLUMN ${entry.key} ${entry.value}');
            print('✅ Added column: ${entry.key}');
          } catch (e) {
            print('⚠️ Could not add column ${entry.key}: $e');
          }
        }
      }
      
      // Migrate old columns if they exist
      try {
        if (columnNames.contains('quantity') && !columnNames.contains('raw_count')) {
          await db.execute('ALTER TABLE produced_products ADD COLUMN raw_count INTEGER DEFAULT 0');
          await db.execute('UPDATE produced_products SET raw_count = CAST(quantity AS INTEGER) WHERE quantity IS NOT NULL');
          print('✅ Migrated quantity to raw_count');
        }
      } catch (e) {
        print('⚠️ Could not migrate quantity: $e');
      }
      
      try {
        if (columnNames.contains('weight') && !columnNames.contains('raw_weight')) {
          await db.execute('ALTER TABLE produced_products ADD COLUMN raw_weight REAL DEFAULT 0');
          await db.execute('UPDATE produced_products SET raw_weight = CAST(weight AS REAL) WHERE weight IS NOT NULL');
          print('✅ Migrated weight to raw_weight');
        }
      } catch (e) {
        print('⚠️ Could not migrate weight: $e');
      }
      
      try {
        if (columnNames.contains('total_weight')) {
          final colInfo = await db.rawQuery("PRAGMA table_info('produced_products')");
          final totalWeightCol = colInfo.firstWhere(
            (col) => col['name']?.toString() == 'total_weight',
            orElse: () => {},
          );
          final type = totalWeightCol['type']?.toString() ?? '';
          if (type.contains('TEXT') || type.contains('VARCHAR')) {
            try {
              await db.execute('ALTER TABLE produced_products ADD COLUMN total_weight_new REAL');
              await db.execute('UPDATE produced_products SET total_weight_new = CAST(total_weight AS REAL) WHERE total_weight IS NOT NULL AND total_weight != ""');
              await db.execute('ALTER TABLE produced_products RENAME COLUMN total_weight TO total_weight_old');
              await db.execute('ALTER TABLE produced_products RENAME COLUMN total_weight_new TO total_weight');
              await db.execute('ALTER TABLE produced_products DROP COLUMN total_weight_old');
              print('✅ Migrated total_weight from TEXT to REAL');
            } catch (e) {
              print('⚠️ Could not migrate total_weight type: $e');
            }
          }
        }
      } catch (e) {
        print('⚠️ Could not check total_weight type: $e');
      }
    }
    
    // Ensure remaining_stock exists
    try {
      await db.execute('ALTER TABLE produced_products ADD COLUMN remaining_stock REAL DEFAULT 0');
      print('✅ Added remaining_stock column');
    } catch (e) {
      // Column already exists
    }
    
    print('✅ produced_products table verified/updated!');
    
  } catch (e) {
    print('❌ Error ensuring produced_products table: $e');
    rethrow;
  }
}

  Future<void> _ensureCapitalTables(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS capital_assets(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          asset_type TEXT NOT NULL,
          name TEXT NOT NULL,
          current_balance REAL NOT NULL,
          initial_balance REAL NOT NULL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS capital_transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          asset_type TEXT NOT NULL,
          asset_name TEXT NOT NULL,
          transaction_type TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          date TEXT,
          date_en TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    } catch (e) {
      print('❌ Error ensuring capital tables: $e');
      rethrow;
    }
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    try {
      final result = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name=?", [tableName]);
      return result.isNotEmpty;
    } catch (e) {
      print('⚠️ Error checking table $tableName: $e');
      return false;
    }
  }

  // ============ PRODUCT STOCK MANAGEMENT ============

  Future<bool> deductProductStock(int productId, double weightToDeduct, String unit) async {
    try {
      final db = await database;
      
      final product = await db.query(
        'produced_products',
        where: 'id = ?',
        whereArgs: [productId],
      );
      
      if (product.isEmpty) {
        print('❌ Product not found: $productId');
        return false;
      }
      
      final currentStock = double.tryParse(product.first['remaining_stock']?.toString() ?? '0') ?? 0;
      final productUnit = product.first['unit']?.toString() ?? '';
      final totalWeight = double.tryParse(product.first['total_weight']?.toString() ?? '0') ?? 0;
      
      double weightToDeductInKg = _convertToKg(weightToDeduct, unit);
      double currentStockInKg = _convertToKg(currentStock, productUnit);
      
      if (currentStock == 0 && totalWeight > 0) {
        await db.update(
          'produced_products',
          {'remaining_stock': totalWeight},
          where: 'id = ?',
          whereArgs: [productId],
        );
        currentStockInKg = _convertToKg(totalWeight, productUnit);
      }
      
      if (weightToDeductInKg > currentStockInKg) {
        print('❌ Insufficient stock! Available: ${currentStockInKg}kg, Requested: ${weightToDeductInKg}kg');
        return false;
      }
      
      double newStockInKg = currentStockInKg - weightToDeductInKg;
      double newStockInProductUnit = _convertFromKg(newStockInKg, productUnit);
      
      await db.update(
        'produced_products',
        {'remaining_stock': newStockInProductUnit},
        where: 'id = ?',
        whereArgs: [productId],
      );
      
      print('✅ Product $productId stock updated: ${currentStockInKg}kg -> ${newStockInKg}kg');
      return true;
      
    } catch (e) {
      print('❌ Error deducting product stock: $e');
      return false;
    }
  }

  double _convertToKg(double weight, String unit) {
    if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
      return weight;
    } else if (unit == 'تن' || unit == 'ton' || unit == 'Ton') {
      return weight * 1000;
    }
    return weight;
  }

  double _convertFromKg(double weightInKg, String unit) {
    if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
      return weightInKg;
    } else if (unit == 'تن' || unit == 'ton' || unit == 'Ton') {
      return weightInKg / 1000;
    }
    return weightInKg;
  }

  Future<Map<String, dynamic>> getProductStock(int productId) async {
    try {
      final db = await database;
      final product = await db.query(
        'produced_products',
        where: 'id = ?',
        whereArgs: [productId],
      );
      
      if (product.isEmpty) {
        return {'stock': 0, 'unit': '', 'available': false};
      }
      
      final stock = double.tryParse(product.first['remaining_stock']?.toString() ?? '0') ?? 0;
      final unit = product.first['unit']?.toString() ?? '';
      final totalWeight = double.tryParse(product.first['total_weight']?.toString() ?? '0') ?? 0;
      
      final availableStock = stock > 0 ? stock : totalWeight;
      
      return {
        'stock': availableStock,
        'unit': unit,
        'available': true,
        'product_name': product.first['product_name']?.toString() ?? '',
      };
    } catch (e) {
      print('❌ Error getting product stock: $e');
      return {'stock': 0, 'unit': '', 'available': false};
    }
  }

  Future<List<Map<String, dynamic>>> getProducedProductsWithStock() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT 
          p.*,
          CASE 
            WHEN p.remaining_stock IS NOT NULL AND p.remaining_stock > 0 THEN p.remaining_stock
            ELSE p.total_weight
          END AS available_stock,
          CASE 
            WHEN p.remaining_stock IS NOT NULL AND p.remaining_stock > 0 THEN 'remaining'
            ELSE 'total'
          END AS stock_type
        FROM produced_products p
        ORDER BY p.created_at DESC
      ''');
      return result;
    } catch (e) {
      print('❌ Error getting products with stock: $e');
      return [];
    }
  }

  Future<bool> _tableHasColumn(Database db, String tableName, String columnName) async {
    try {
      final result = await db.rawQuery('PRAGMA table_info($tableName)');
      return result.any((row) => row['name']?.toString() == columnName);
    } catch (e) {
      print('⚠️ Error checking column $columnName in $tableName: $e');
      return false;
    }
  }

  Future<void> _repairSarafiTransactionsTable(Database db) async {
    try {
      final tableExists = await _tableExists(db, 'sarafi_transactions');
      if (!tableExists) {
        await db.execute('''
          CREATE TABLE sarafi_transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER,
            transaction_type TEXT NOT NULL,
            amount_usd REAL NOT NULL,
            exchange_rate REAL NOT NULL DEFAULT 1,
            amount_afn REAL NOT NULL DEFAULT 0,
            balance_after REAL NOT NULL DEFAULT 0,
            source_name TEXT,
            source_account TEXT,
            source_email TEXT,
            source_phone TEXT,
            date TEXT,
            date_en TEXT,
            address TEXT,
            note TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (account_id) REFERENCES sarafi_accounts (id)
          )
        ''');
        return;
      }

      final columns = await db.rawQuery('PRAGMA table_info(sarafi_transactions)');
      final columnNames = columns.map((row) => row['name']?.toString()).toSet();

      if (!columnNames.contains('account_id')) {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN account_id INTEGER');
      }
      if (!columnNames.contains('exchange_rate')) {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN exchange_rate REAL NOT NULL DEFAULT 1');
      }
      if (!columnNames.contains('amount_afn')) {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN amount_afn REAL NOT NULL DEFAULT 0');
      }
      if (!columnNames.contains('balance_after')) {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN balance_after REAL NOT NULL DEFAULT 0');
      }
      if (!columnNames.contains('amount_usd')) {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN amount_usd REAL NOT NULL DEFAULT 0');
      }
      if (!columnNames.contains('source_name')) {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN source_name TEXT');
      }
      if (!columnNames.contains('source_account')) {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN source_account TEXT');
      }
      if (!columnNames.contains('source_email')) {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN source_email TEXT');
      }
      if (!columnNames.contains('source_phone')) {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN source_phone TEXT');
      }
      if (!columnNames.contains('date')) {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN date TEXT');
      }
      if (!columnNames.contains('date_en')) {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN date_en TEXT');
      }
      if (!columnNames.contains('address')) {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN address TEXT');
      }
      if (!columnNames.contains('note')) {
        await db.execute('ALTER TABLE sarafi_transactions ADD COLUMN note TEXT');
      }

      await db.execute("UPDATE sarafi_transactions SET account_id = 1 WHERE account_id IS NULL");
      await db.execute("UPDATE sarafi_transactions SET exchange_rate = 1 WHERE exchange_rate IS NULL");
      await db.execute("UPDATE sarafi_transactions SET amount_afn = 0 WHERE amount_afn IS NULL");
      await db.execute("UPDATE sarafi_transactions SET balance_after = 0 WHERE balance_after IS NULL");
    } catch (e) {
      print('⚠️ Error repairing sarafi_transactions schema: $e');
    }
  }

  Future<void> _ensureSarafiTables(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sarafi_accounts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_number TEXT NOT NULL UNIQUE,
          current_usd_balance REAL NOT NULL,
          initial_usd_balance REAL NOT NULL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sarafi_transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER,
          transaction_type TEXT NOT NULL,
          amount_usd REAL NOT NULL,
          exchange_rate REAL NOT NULL DEFAULT 1,
          amount_afn REAL NOT NULL DEFAULT 0,
          balance_after REAL NOT NULL DEFAULT 0,
          source_name TEXT,
          source_account TEXT,
          source_email TEXT,
          source_phone TEXT,
          date TEXT,
          date_en TEXT,
          address TEXT,
          note TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (account_id) REFERENCES sarafi_accounts (id)
        )
      ''');

      await _repairSarafiTransactionsTable(db);
    } catch (e) {
      print('❌ Error ensuring sarafi tables: $e');
      rethrow;
    }
  }

  Future<void> _ensureCustomerCompanyTables(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          nickname TEXT,
          phone TEXT,
          email TEXT,
          address TEXT,
          type TEXT,
          transactions TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS companies(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          email TEXT,
          address TEXT,
          type TEXT,
          transactions TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''' );
    } catch (e) {
      print('❌ Error ensuring customer/company tables: $e');
      rethrow;
    }
  }

  Future<void> _ensureDailyExpensesTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_expenses(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          registration_number TEXT UNIQUE,
          date TEXT,
          date_en TEXT,
          category TEXT,
          description TEXT,
          price REAL,
          currency TEXT,
          exchange_rate REAL,
          usd_equivalent REAL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    } catch (e) {
      print('❌ Error ensuring daily_expenses table: $e');
      rethrow;
    }
  }

  Future<void> _ensureWasteMaterialsTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS waste_material_losses(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_number TEXT UNIQUE,
          party_details TEXT,
          waste_type TEXT,
          weight REAL,
          quantity REAL,
          value REAL,
          currency TEXT,
          exchange_rate REAL,
          afn_equivalent REAL,
          description TEXT,
          date TEXT,
          date_en TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    } catch (e) {
      print('❌ Error ensuring waste_material_losses table: $e');
      rethrow;
    }
  }

  Future<void> _ensureServiceInvoicesTable(Database db) async {
    try {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='service_invoices'");
      
      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE service_invoices(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_number TEXT NOT NULL UNIQUE,
            customer_name TEXT,
            customer_phone TEXT,
            customer_address TEXT,
            service_title TEXT,
            service_type TEXT,
            description TEXT,
            size TEXT,
            thickness TEXT,
            total_weight REAL,
            unit TEXT,
            unit_price REAL,
            total_price REAL,
            price REAL,
            currency TEXT,
            exchange_rate REAL,
            loading_cost REAL,
            transfer_cost REAL,
            clearance_cost REAL,
            discount REAL,
            final_price REAL,
            afn_equivalent REAL,
            date TEXT,
            date_en TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        print('✅ service_invoices table created with invoice_number!');
      } else {
        final columns = await db.rawQuery("PRAGMA table_info('service_invoices')");
        final columnNames = columns.map((c) => c['name']?.toString()).whereType<String>().toSet();
        
        if (!columnNames.contains('invoice_number')) {
          await db.execute('ALTER TABLE service_invoices ADD COLUMN invoice_number TEXT');
          print('✅ Added invoice_number column to service_invoices');
          await db.execute('UPDATE service_invoices SET invoice_number = "SERV" || substr("00000" || id, -5, 5) WHERE invoice_number IS NULL OR invoice_number = ""');
          print('✅ Updated existing service invoices with invoice numbers');
        }
        
        if (!columnNames.contains('customer_phone')) {
          await db.execute('ALTER TABLE service_invoices ADD COLUMN customer_phone TEXT');
        }
        if (!columnNames.contains('customer_address')) {
          await db.execute('ALTER TABLE service_invoices ADD COLUMN customer_address TEXT');
        }
        if (!columnNames.contains('size')) {
          await db.execute('ALTER TABLE service_invoices ADD COLUMN size TEXT');
        }
        if (!columnNames.contains('thickness')) {
          await db.execute('ALTER TABLE service_invoices ADD COLUMN thickness TEXT');
        }
        if (!columnNames.contains('total_weight')) {
          await db.execute('ALTER TABLE service_invoices ADD COLUMN total_weight REAL');
        }
        if (!columnNames.contains('unit')) {
          await db.execute('ALTER TABLE service_invoices ADD COLUMN unit TEXT');
        }
        if (!columnNames.contains('unit_price')) {
          await db.execute('ALTER TABLE service_invoices ADD COLUMN unit_price REAL');
        }
        if (!columnNames.contains('total_price')) {
          await db.execute('ALTER TABLE service_invoices ADD COLUMN total_price REAL');
        }
        if (!columnNames.contains('price')) {
          await db.execute('ALTER TABLE service_invoices ADD COLUMN price REAL');
        }
        if (!columnNames.contains('service_title')) {
          await db.execute('ALTER TABLE service_invoices ADD COLUMN service_title TEXT');
        }
        if (!columnNames.contains('description')) {
          await db.execute('ALTER TABLE service_invoices ADD COLUMN description TEXT');
        }
        
        print('✅ service_invoices table verified/updated');
      }
    } catch (e) {
      print('❌ Error ensuring service invoices table: $e');
      rethrow;
    }
  }

Future<void> _ensureSalesInvoiceTable(Database db) async {
  try {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_invoices(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        customer_name TEXT,
        customer_phone TEXT,
        customer_address TEXT,
        customer_company TEXT,
        product_name TEXT,
        gender TEXT,
        size TEXT,
        thickness TEXT,
        weight TEXT,
        weight_per_unit TEXT,
        unit_count TEXT,
        total_weight TEXT,
        unit TEXT,
        unit_price REAL,
        total_price REAL,
        price_rate REAL,
        currency TEXT,
        usd_equivalent REAL,
        afn_equivalent REAL,
        loading_cost REAL,
        transfer_cost REAL,
        clearance_cost REAL,
        discount REAL,
        loading_time TEXT,
        loading_time_en TEXT,
        final_price REAL,
        payment_method TEXT,
        loan_type TEXT,
        paid_amount REAL DEFAULT 0,
        remaining_amount REAL DEFAULT 0,
        description TEXT,
        sale_type TEXT,
        date TEXT,
        date_en TEXT,
        is_back_returned INTEGER DEFAULT 0,
        back_return_reason TEXT,
        back_return_date TEXT,
        back_return_date_en TEXT,
        produced_product_id INTEGER,
        driver_name TEXT,
        number_plate TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Try adding columns individually if they don't exist
    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN driver_name TEXT');
      print('✅ Added driver_name column');
    } catch (e) {
      print('⚠️ driver_name column already exists: $e');
    }

    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN number_plate TEXT');
      print('✅ Added number_plate column');
    } catch (e) {
      print('⚠️ number_plate column already exists: $e');
    }

    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN loading_time_en TEXT');
    } catch (e) {
      print('⚠️ loading_time_en column already exists or could not be added: $e');
    }
    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN price_rate REAL');
    } catch (e) {
      print('⚠️ price_rate column already exists or could not be added: $e');
    }
    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN payment_method TEXT');
    } catch (e) {
      print('⚠️ payment_method column already exists or could not be added: $e');
    }
    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN loan_type TEXT');
    } catch (e) {
      print('⚠️ loan_type column already exists or could not be added: $e');
    }
    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN paid_amount REAL DEFAULT 0');
    } catch (e) {
      print('⚠️ paid_amount column already exists or could not be added: $e');
    }
    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN remaining_amount REAL DEFAULT 0');
    } catch (e) {
      print('⚠️ remaining_amount column already exists or could not be added: $e');
    }
    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN is_back_returned INTEGER DEFAULT 0');
    } catch (e) {
      print('⚠️ is_back_returned column already exists or could not be added: $e');
    }
    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN back_return_reason TEXT');
    } catch (e) {
      print('⚠️ back_return_reason column already exists or could not be added: $e');
    }
    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN back_return_date TEXT');
    } catch (e) {
      print('⚠️ back_return_date column already exists or could not be added: $e');
    }
    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN back_return_date_en TEXT');
    } catch (e) {
      print('⚠️ back_return_date_en column already exists or could not be added: $e');
    }
    try {
      await db.execute('ALTER TABLE sales_invoices ADD COLUMN produced_product_id INTEGER');
    } catch (e) {
      print('⚠️ produced_product_id column already exists or could not be added: $e');
    }
    
  } catch (e) {
    print('❌ Error ensuring sales invoices table: $e');
    rethrow;
  }
}

  Future<Map<String, dynamic>> _filterMapForTableColumns(Database db, String tableName, Map<String, dynamic> values) async {
    final cols = await db.rawQuery("PRAGMA table_info('$tableName')");
    final columnNames = <String>{};
    for (final c in cols) {
      final name = c['name']?.toString();
      if (name != null) columnNames.add(name);
    }
    final filtered = <String, dynamic>{};
    values.forEach((k, v) {
      if (columnNames.contains(k)) filtered[k] = v;
    });
    return filtered;
  }

 Future<void> _createTables(Database db) async {
  await db.execute('''
    CREATE TABLE users(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      full_name TEXT NOT NULL,
      email TEXT,
      role TEXT DEFAULT 'admin',
      profile_pic TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await db.execute('''
    CREATE TABLE products(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      price REAL NOT NULL,
      stock INTEGER NOT NULL,
      category TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await db.execute('''
    CREATE TABLE suppliers(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      email TEXT,
      address TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await db.execute('''
    CREATE TABLE raw_materials(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      supplier_id INTEGER,
      name TEXT NOT NULL,
      location TEXT,
      material_type TEXT,
      thickness TEXT,
      net_weight TEXT,
      gross_weight TEXT,
      date TEXT,
      date_en TEXT,
      unit TEXT,
      unit_price TEXT,
      product TEXT,
      commission TEXT,
      transfer_cost TEXT,
      miscellaneous TEXT,
      ghurfedari TEXT,
      barchalani TEXT,
      purchase_type TEXT,
      seller_payment TEXT,
      seller_payment_method TEXT,
      seller_paid_amount TEXT,
      currency TEXT,
      exchange_rate REAL,
      final_price TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
    )
  ''');

  // UPDATED: product_name is no longer NOT NULL
  await db.execute('''
    CREATE TABLE produced_products(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_name TEXT,
      production_type TEXT,
      size TEXT,
      thickness TEXT,
      length TEXT,
      raw_count INTEGER,
      raw_weight REAL,
      total_weight REAL,
      unit TEXT,
      production_date TEXT,
      production_date_en TEXT,
      status TEXT,
      description TEXT,
      remaining_stock REAL DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await db.execute('''
    CREATE TABLE capital_assets(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      asset_type TEXT NOT NULL,
      name TEXT NOT NULL,
      current_balance REAL NOT NULL,
      initial_balance REAL NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await db.execute('''
    CREATE TABLE capital_transactions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      asset_type TEXT NOT NULL,
      asset_name TEXT NOT NULL,
      transaction_type TEXT NOT NULL,
      amount REAL NOT NULL,
      description TEXT,
      date TEXT,
      date_en TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await _ensureSupplierLoanTables(db);
  await _ensureSellLoanTables(db);
  await _ensureSalesInvoiceTable(db);
  await _ensureServiceInvoicesTable(db);
  await _ensureDailyExpensesTable(db);
  await _ensureSalesInvoiceProductRelation(db);
}

  Future<void> _insertSampleData(Database db) async {
    await db.insert('users', {
      'username': 'admin',
      'password': 'admin123',
      'full_name': 'مدیر سیستم',
      'email': 'admin@victorpipe.com',
      'role': 'admin',
      'profile_pic': null,
    });
    
    await db.insert('users', {
      'username': 'reza',
      'password': 'reza123',
      'full_name': 'رضا احمدی',
      'email': 'reza@victorpipe.com',
      'role': 'admin',
      'profile_pic': null,
    });
    
    await db.insert('products', {
      'name': 'لوله PVC',
      'price': 25000,
      'stock': 120,
      'category': 'لوله',
    });
    await db.insert('products', {
      'name': 'اتصال زانویی',
      'price': 8500,
      'stock': 300,
      'category': 'اتصالات',
    });
    await db.insert('products', {
      'name': 'چسب پی وی سی',
      'price': 12000,
      'stock': 80,
      'category': 'مواد مصرفی',
    });

    await db.insert('suppliers', {
      'name': 'تامین پلیمر تهران',
      'phone': '021 1234 5678',
      'email': 'info@taminpolimer.com',
      'address': 'تهران، خیابان آزادی، پلاک ۱۲۳',
    });
  }

  // ============ USERS ============
  Future<Map<String, dynamic>?> loginUser(String username, String password) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        'users',
        where: 'username = ? AND password = ?',
        whereArgs: [username, password],
      );
      if (result.isNotEmpty) {
        print('✅ Login successful for: ${result.first['full_name']}');
        return result.first;
      }
      print('❌ Login failed');
      return null;
    } catch (e) {
      print('❌ Login error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final db = await database;
      return await db.query('users');
    } catch (e) {
      print('❌ Error getting users: $e');
      return [];
    }
  }

  // ============ ADMIN MANAGEMENT ============
  Future<List<Map<String, dynamic>>> getAdmins() async {
    try {
      final db = await database;
      return await db.query(
        'users',
        where: 'role = ?',
        whereArgs: ['admin'],
        orderBy: 'full_name ASC',
      );
    } catch (e) {
      print('❌ Error getting admins: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getAdminById(int id) async {
    try {
      final db = await database;
      final result = await db.query(
        'users',
        where: 'id = ? AND role = ?',
        whereArgs: [id, 'admin'],
      );
      if (result.isNotEmpty) return result.first;
      return null;
    } catch (e) {
      print('❌ Error getting admin: $e');
      return null;
    }
  }

  Future<int> insertAdmin(Map<String, dynamic> admin) async {
    try {
      final db = await database;
      final existing = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [admin['username']],
      );
      if (existing.isNotEmpty) {
        throw Exception('نام کاربری قبلاً ثبت شده است');
      }
      return await db.insert('users', admin);
    } catch (e) {
      print('❌ Error inserting admin: $e');
      rethrow;
    }
  }

  Future<int> updateAdmin(int id, Map<String, dynamic> admin) async {
    try {
      final db = await database;
      final existing = await db.query(
        'users',
        where: 'username = ? AND id != ?',
        whereArgs: [admin['username'], id],
      );
      if (existing.isNotEmpty) {
        throw Exception('نام کاربری قبلاً ثبت شده است');
      }
      return await db.update(
        'users',
        admin,
        where: 'id = ? AND role = ?',
        whereArgs: [id, 'admin'],
      );
    } catch (e) {
      print('❌ Error updating admin: $e');
      rethrow;
    }
  }

  Future<int> deleteAdmin(int id) async {
    try {
      final db = await database;
      final admins = await db.query(
        'users',
        where: 'role = ?',
        whereArgs: ['admin'],
      );
      if (admins.length <= 1) {
        throw Exception('حداقل یک مدیر باید در سیستم وجود داشته باشد');
      }
      return await db.delete(
        'users',
        where: 'id = ? AND role = ?',
        whereArgs: [id, 'admin'],
      );
    } catch (e) {
      print('❌ Error deleting admin: $e');
      rethrow;
    }
  }

  Future<bool> isAdminExists(String username) async {
    try {
      final db = await database;
      final result = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
      );
      return result.isNotEmpty;
    } catch (e) {
      print('❌ Error checking admin: $e');
      return false;
    }
  }

  // ============ PRODUCTS ============
  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final db = await database;
      return await db.query('products');
    } catch (e) {
      print('❌ Error getting products: $e');
      return [];
    }
  }

  Future<int> insertProduct(Map<String, dynamic> product) async {
    try {
      final db = await database;
      return await db.insert('products', product);
    } catch (e) {
      print('❌ Error inserting product: $e');
      return -1;
    }
  }

  Future<int> updateProduct(int id, Map<String, dynamic> product) async {
    try {
      final db = await database;
      return await db.update(
        'products',
        product,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Error updating product: $e');
      return -1;
    }
  }

  Future<int> deleteProduct(int id) async {
    try {
      final db = await database;
      return await db.delete(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Error deleting product: $e');
      return -1;
    }
  }

  // ============ SUPPLIERS ============
  Future<List<Map<String, dynamic>>> getSuppliers() async {
    try {
      final db = await database;
      return await db.query('suppliers', orderBy: 'name ASC');
    } catch (e) {
      print('❌ Error getting suppliers: $e');
      return [];
    }
  }

  Future<int> insertSupplier(Map<String, dynamic> supplier) async {
    try {
      final db = await database;
      return await db.insert('suppliers', supplier);
    } catch (e) {
      print('❌ Error inserting supplier: $e');
      return -1;
    }
  }

  Future<int> updateSupplier(int id, Map<String, dynamic> supplier) async {
    try {
      final db = await database;
      return await db.update(
        'suppliers',
        supplier,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Error updating supplier: $e');
      return -1;
    }
  }

  Future<int> deleteSupplier(int id) async {
    try {
      final db = await database;
      return await db.delete(
        'suppliers',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Error deleting supplier: $e');
      return -1;
    }
  }

  // ============ CUSTOMERS & COMPANIES ============
  Future<List<Map<String, dynamic>>> getCustomers() async {
    try {
      final db = await database;
      return await db.query('customers', orderBy: 'name ASC');
    } catch (e) {
      print('❌ Error getting customers: $e');
      return [];
    }
  }

  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    try {
      final db = await database;
      return await db.insert('customers', customer);
    } catch (e) {
      print('❌ Error inserting customer: $e');
      return -1;
    }
  }

  Future<int> updateCustomer(int id, Map<String, dynamic> customer) async {
    try {
      final db = await database;
      return await db.update('customers', customer, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error updating customer: $e');
      return -1;
    }
  }

  Future<int> deleteCustomer(int id) async {
    try {
      final db = await database;
      return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error deleting customer: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getCompanies() async {
    try {
      final db = await database;
      return await db.query('companies', orderBy: 'name ASC');
    } catch (e) {
      print('❌ Error getting companies: $e');
      return [];
    }
  }

  Future<int> insertCompany(Map<String, dynamic> company) async {
    try {
      final db = await database;
      return await db.insert('companies', company);
    } catch (e) {
      print('❌ Error inserting company: $e');
      return -1;
    }
  }

  Future<int> updateCompany(int id, Map<String, dynamic> company) async {
    try {
      final db = await database;
      return await db.update('companies', company, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error updating company: $e');
      return -1;
    }
  }

  Future<int> deleteCompany(int id) async {
    try {
      final db = await database;
      return await db.delete('companies', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error deleting company: $e');
      return -1;
    }
  }

  // ============ SALES INVOICES ============
  Future<List<Map<String, dynamic>>> getSalesInvoices({bool onlyReturned = false}) async {
    try {
      final db = await database;
      if (onlyReturned) {
        return await db.query('sales_invoices', where: 'is_back_returned = ?', whereArgs: [1], orderBy: 'created_at DESC');
      }
      return await db.query('sales_invoices', orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting sales invoices: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSalesInvoiceById(int id) async {
    try {
      final db = await database;
      final result = await db.query('sales_invoices', where: 'id = ?', whereArgs: [id]);
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('❌ Error getting sales invoice by id: $e');
      return null;
    }
  }

  Future<int> updateSalesInvoice(int id, Map<String, dynamic> invoice) async {
    try {
      final db = await database;
      final filtered = await _filterMapForTableColumns(db, 'sales_invoices', invoice);
      if (filtered.isEmpty) {
        print('⚠️ updateSalesInvoice filtered empty - sales_invoices table may not exist or payload had no valid columns');
        return -1;
      }
      return await db.update('sales_invoices', filtered, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error updating sales invoice: $e');
      return -1;
    }
  }

  Future<int> getNextSalesInvoiceNumber() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT MAX(CAST(invoice_number AS INTEGER)) AS max_invoice FROM sales_invoices');
      final maxInvoice = result.isNotEmpty ? result.first['max_invoice'] : null;
      final currentValue = maxInvoice is int ? maxInvoice : int.tryParse(maxInvoice?.toString() ?? '') ?? 9999;
      return currentValue + 1;
    } catch (e) {
      print('❌ Error getting next invoice number: $e');
      return 10000;
    }
  }

  Future<int> insertSalesInvoice(Map<String, dynamic> invoice) async {
    try {
      final db = await database;
      final filtered = await _filterMapForTableColumns(db, 'sales_invoices', invoice);
      if (filtered.isEmpty) {
        print('⚠️ insertSalesInvoice filtered empty - sales_invoices table may not exist or payload had no valid columns');
        return -1;
      }
      return await db.insert('sales_invoices', filtered);
    } catch (e) {
      print('❌ Error inserting sales invoice: $e');
      return -1;
    }
  }

  Future<int> deleteSalesInvoice(int id) async {
    try {
      final db = await database;
      return await db.delete('sales_invoices', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error deleting sales invoice: $e');
      return -1;
    }
  }

  Future<Map<String, dynamic>?> getSalesInvoiceByNumber(String invoiceNumber) async {
    try {
      final db = await database;
      final result = await db.query(
        'sales_invoices',
        where: 'invoice_number = ?',
        whereArgs: [invoiceNumber],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('❌ Error getting sales invoice by number: $e');
      return null;
    }
  }

  // ============ SERVICE INVOICES ============
  Future<List<Map<String, dynamic>>> getServiceInvoices() async {
    try {
      final db = await database;
      return await db.query('service_invoices', orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting service invoices: $e');
      return [];
    }
  }

  Future<int> getNextServiceInvoiceNumber() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT MAX(CAST(invoice_number AS INTEGER)) AS max_invoice FROM service_invoices');
      final maxInvoice = result.isNotEmpty ? result.first['max_invoice'] : null;
      final currentValue = maxInvoice is int ? maxInvoice : int.tryParse(maxInvoice?.toString() ?? '') ?? 9999;
      return currentValue + 1;
    } catch (e) {
      print('❌ Error getting next service invoice number: $e');
      return 10000;
    }
  }

  Future<int> insertServiceInvoice(Map<String, dynamic> invoice) async {
    try {
      final db = await database;
      if (invoice['invoice_number'] == null || invoice['invoice_number'].toString().trim().isEmpty) {
        print('❌ invoice_number is required but was not provided');
        return -1;
      }
      
      final filtered = await _filterMapForTableColumns(db, 'service_invoices', invoice);
      if (filtered.isEmpty) {
        print('⚠️ insertServiceInvoice filtered empty - service_invoices table may not exist or payload had no valid columns');
        return -1;
      }
      return await db.insert('service_invoices', filtered);
    } catch (e) {
      print('❌ Error inserting service invoice: $e');
      return -1;
    }
  }

  Future<int> updateServiceInvoice(int id, Map<String, dynamic> invoice) async {
    try {
      final db = await database;
      final filtered = await _filterMapForTableColumns(db, 'service_invoices', invoice);
      if (filtered.isEmpty) {
        print('⚠️ updateServiceInvoice filtered empty - service_invoices table may not exist or payload had no valid columns');
        return -1;
      }
      return await db.update('service_invoices', filtered, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error updating service invoice: $e');
      return -1;
    }
  }

  Future<int> deleteServiceInvoice(int id) async {
    try {
      final db = await database;
      return await db.delete('service_invoices', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error deleting service invoice: $e');
      return -1;
    }
  }

  Future<Map<String, dynamic>?> getServiceInvoiceByNumber(String invoiceNumber) async {
    try {
      final db = await database;
      final result = await db.query(
        'service_invoices',
        where: 'invoice_number = ?',
        whereArgs: [invoiceNumber],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('❌ Error getting service invoice by number: $e');
      return null;
    }
  }

  // ============ SUPPLIER LOANS ============
  Future<int> insertSupplierLoan(Map<String, dynamic> loan) async {
    try {
      final db = await database;
      final filtered = await _filterMapForTableColumns(db, 'supplier_loans', loan);
      if (filtered.isEmpty) {
        print('⚠️ insertSupplierLoan filtered empty - supplier_loans table may not exist or payload had no valid columns');
        return -1;
      }
      return await db.insert('supplier_loans', filtered);
    } catch (e) {
      print('❌ Error inserting supplier loan: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getSupplierLoans({int? supplierId}) async {
    try {
      final db = await database;
      String? whereClause;
      final List<dynamic> whereArgs = [];

      if (supplierId != null) {
        whereClause = 'supplier_id = ?';
        whereArgs.add(supplierId);
      }

      if (whereClause != null && whereClause.isNotEmpty) {
        return await db.query('supplier_loans', where: whereClause, whereArgs: whereArgs, orderBy: 'created_at DESC');
      }

      return await db.query('supplier_loans', orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting supplier loans: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSupplierLoanById(int id) async {
    try {
      final db = await database;
      final result = await db.query('supplier_loans', where: 'id = ?', whereArgs: [id]);
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('❌ Error getting supplier loan by id: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSupplierLoanByInvoiceNumber(String invoiceNumber) async {
    try {
      final db = await database;
      final result = await db.query('supplier_loans', where: 'invoice_number = ?', whereArgs: [invoiceNumber], limit: 1);
      if (result.isNotEmpty) return result.first;
      return null;
    } catch (e) {
      print('❌ Error getting supplier loan by invoice number: $e');
      return null;
    }
  }

  Future<int> updateSupplierLoanPaid(int loanId, double paidAmount, double remainingAmount) async {
    try {
      final db = await database;
      return await db.update('supplier_loans', {'paid_amount': paidAmount, 'remaining_amount': remainingAmount}, where: 'id = ?', whereArgs: [loanId]);
    } catch (e) {
      print('❌ Error updating supplier loan paid/remaining: $e');
      return -1;
    }
  }

  Future<int> insertSupplierLoanPayment(Map<String, dynamic> payment) async {
    try {
      final db = await database;
      if (payment.isEmpty) {
        print('⚠️ insertSupplierLoanPayment called with empty payment');
        return -1;
      }
      final filtered = await _filterMapForTableColumns(db, 'supplier_loan_payments', payment);
      if (filtered.isEmpty) {
        print('⚠️ insertSupplierLoanPayment filtered empty - supplier_loan_payments table may not exist or payload had no valid columns');
        return -1;
      }
      return await db.insert('supplier_loan_payments', filtered);
    } catch (e) {
      print('❌ Error inserting supplier loan payment: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getSupplierLoanPayments(int loanId) async {
    try {
      final db = await database;
      return await db.query('supplier_loan_payments', where: 'loan_id = ?', whereArgs: [loanId], orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting supplier loan payments: $e');
      return [];
    }
  }

  // ============ SELL LOANS (Customer Loans) ============
  Future<int> insertSellLoan(Map<String, dynamic> loan) async {
    try {
      final db = await database;
      final filtered = await _filterMapForTableColumns(db, 'sell_loans', loan);
      if (filtered.isEmpty) {
        print('⚠️ insertSellLoan filtered empty - sell_loans table may not exist or payload had no valid columns');
        return -1;
      }
      return await db.insert('sell_loans', filtered);
    } catch (e) {
      print('❌ Error inserting sell loan: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getSellLoans() async {
    try {
      final db = await database;
      return await db.query('sell_loans', orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting sell loans: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSellLoanById(int id) async {
    try {
      final db = await database;
      final result = await db.query('sell_loans', where: 'id = ?', whereArgs: [id]);
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('❌ Error getting sell loan by id: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSellLoanByInvoiceNumber(String invoiceNumber) async {
    try {
      final db = await database;
      final result = await db.query('sell_loans', where: 'invoice_number = ?', whereArgs: [invoiceNumber], limit: 1);
      if (result.isNotEmpty) return result.first;
      return null;
    } catch (e) {
      print('❌ Error getting sell loan by invoice number: $e');
      return null;
    }
  }

  Future<int> updateSellLoanPaid(int loanId, double paidAmount, double remainingAmount) async {
    try {
      final db = await database;
      return await db.update('sell_loans', {'paid_amount': paidAmount, 'remaining_amount': remainingAmount}, where: 'id = ?', whereArgs: [loanId]);
    } catch (e) {
      print('❌ Error updating sell loan paid/remaining: $e');
      return -1;
    }
  }

  Future<int> insertSellLoanPayment(Map<String, dynamic> payment) async {
    try {
      final db = await database;
      if (payment.isEmpty) {
        print('⚠️ insertSellLoanPayment called with empty payment');
        return -1;
      }
      final filtered = await _filterMapForTableColumns(db, 'sell_loan_payments', payment);
      if (filtered.isEmpty) {
        print('⚠️ insertSellLoanPayment filtered empty - sell_loan_payments table may not exist or payload had no valid columns');
        return -1;
      }
      return await db.insert('sell_loan_payments', filtered);
    } catch (e) {
      print('❌ Error inserting sell loan payment: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getSellLoanPayments(int loanId) async {
    try {
      final db = await database;
      return await db.query('sell_loan_payments', where: 'loan_id = ?', whereArgs: [loanId], orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting sell loan payments: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRawMaterialsBySupplier(int supplierId) async {
    try {
      final db = await database;
      return await db.query('raw_materials', where: 'supplier_id = ?', whereArgs: [supplierId], orderBy: 'date_en DESC');
    } catch (e) {
      print('❌ Error getting raw materials by supplier: $e');
      return [];
    }
  }

  // ============ PRODUCED PRODUCTS CRUD ============
  Future<List<Map<String, dynamic>>> getProducedProducts() async {
    try {
      final db = await database;
      return await db.query('produced_products', orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting produced products: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProducedProductsWithSaleStatus() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT 
          p.*,
          COUNT(s.id) AS sale_count,
          GROUP_CONCAT(s.invoice_number) AS sale_invoices,
          CASE WHEN COUNT(s.id) > 0 THEN 1 ELSE 0 END AS is_sold,
          COALESCE(p.remaining_stock, p.total_weight) AS available_stock
        FROM produced_products p
        LEFT JOIN sales_invoices s ON s.produced_product_id = p.id
        GROUP BY p.id
        ORDER BY p.created_at DESC
      ''');
      return result;
    } catch (e) {
      print('❌ Error getting produced products with sale status: $e');
      return [];
    }
  }

  Future<void> initializeProductStock() async {
    try {
      final db = await database;
      
      try {
        await db.execute('ALTER TABLE produced_products ADD COLUMN total_weight REAL DEFAULT 0');
        print('✅ Added total_weight column to produced_products');
      } catch (e) {
        print('⚠️ total_weight column already exists or could not be added: $e');
      }
      
      await db.execute('''
        UPDATE produced_products 
        SET remaining_stock = total_weight
        WHERE (remaining_stock IS NULL OR remaining_stock = 0) 
        AND total_weight IS NOT NULL AND total_weight > 0
      ''');
      
      await db.execute('''
        UPDATE produced_products 
        SET remaining_stock = CAST(raw_count AS REAL) * raw_weight,
            total_weight = CAST(raw_count AS REAL) * raw_weight
        WHERE (remaining_stock IS NULL OR remaining_stock = 0) 
        AND (total_weight IS NULL OR total_weight = 0)
      ''');
      
      print('✅ Initialized remaining_stock and total_weight for all products');
    } catch (e) {
      print('❌ Error initializing product stock: $e');
    }
  }

  Future<int> insertProducedProduct(Map<String, dynamic> product) async {
    try {
      final db = await database;
      
      final rawCount = int.tryParse(product['raw_count']?.toString() ?? '0') ?? 0;
      final rawWeight = double.tryParse(product['raw_weight']?.toString() ?? '0') ?? 0;
      final totalWeight = rawCount * rawWeight;
      
      product['total_weight'] = totalWeight.toDouble();
      product['remaining_stock'] = totalWeight.toDouble();
      
      return await db.insert('produced_products', product);
    } catch (e) {
      print('❌ Error inserting produced product: $e');
      return -1;
    }
  }

  Future<int> updateProducedProduct(int id, Map<String, dynamic> product) async {
    try {
      final db = await database;
      
      final currentProduct = await db.query(
        'produced_products',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (currentProduct.isNotEmpty) {
        final currentRemainingStock = double.tryParse(currentProduct.first['remaining_stock']?.toString() ?? '0') ?? 0;
        
        if (product.containsKey('raw_count') || product.containsKey('raw_weight')) {
          final rawCount = int.tryParse(product['raw_count']?.toString() ?? '0') ?? 0;
          final rawWeight = double.tryParse(product['raw_weight']?.toString() ?? '0') ?? 0;
          final totalWeight = rawCount * rawWeight;
          product['total_weight'] = totalWeight.toDouble();
          
          final oldTotalWeight = double.tryParse(currentProduct.first['total_weight']?.toString() ?? '0') ?? 0;
          if (currentRemainingStock == oldTotalWeight) {
            product['remaining_stock'] = totalWeight.toDouble();
          } else if (totalWeight > oldTotalWeight) {
            final difference = totalWeight - oldTotalWeight;
            product['remaining_stock'] = currentRemainingStock + difference;
          }
        }
      }
      
      return await db.update(
        'produced_products',
        product,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Error updating produced product: $e');
      return -1;
    }
  }

  Future<int> deleteProducedProduct(int id) async {
    try {
      final db = await database;
      return await db.delete(
        'produced_products',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Error deleting produced product: $e');
      return -1;
    }
  }

  Future<bool> addProductStock(int productId, double weightToAdd, String unit) async {
    try {
      final db = await database;
      
      final product = await db.query(
        'produced_products',
        where: 'id = ?',
        whereArgs: [productId],
      );
      
      if (product.isEmpty) {
        print('❌ Product not found: $productId');
        return false;
      }
      
      final currentStock = double.tryParse(product.first['remaining_stock']?.toString() ?? '0') ?? 0;
      final productUnit = product.first['unit']?.toString() ?? '';
      
      double weightToAddInKg = _convertToKg(weightToAdd, unit);
      double currentStockInKg = _convertToKg(currentStock, productUnit);
      
      double newStockInKg = currentStockInKg + weightToAddInKg;
      double newStockInProductUnit = _convertFromKg(newStockInKg, productUnit);
      
      await db.update(
        'produced_products',
        {'remaining_stock': newStockInProductUnit},
        where: 'id = ?',
        whereArgs: [productId],
      );
      
      print('✅ Product $productId stock updated: ${currentStockInKg}kg + ${weightToAddInKg}kg = ${newStockInKg}kg');
      return true;
      
    } catch (e) {
      print('❌ Error adding product stock: $e');
      return false;
    }
  }

  // ============ CAPITAL ASSETS ============
  Future<List<Map<String, dynamic>>> getCapitalAssets() async {
    try {
      final db = await database;
      return await db.query('capital_assets', orderBy: 'id ASC');
    } catch (e) {
      print('❌ Error getting capital assets: $e');
      return [];
    }
  }

  Future<int> insertCapitalAsset(Map<String, dynamic> asset) async {
    try {
      final db = await database;
      return await db.insert('capital_assets', asset);
    } catch (e) {
      print('❌ Error inserting capital asset: $e');
      return -1;
    }
  }

  Future<int> updateCapitalAsset(int id, Map<String, dynamic> asset) async {
    try {
      final db = await database;
      return await db.update('capital_assets', asset, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error updating capital asset: $e');
      return -1;
    }
  }

  Future<int> deleteCapitalAsset(int id) async {
    try {
      final db = await database;
      return await db.delete('capital_assets', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error deleting capital asset: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getCapitalTransactions() async {
    try {
      final db = await database;
      return await db.query('capital_transactions', orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting capital transactions: $e');
      return [];
    }
  }

  Future<int> insertCapitalTransaction(Map<String, dynamic> transaction) async {
    try {
      final db = await database;
      return await db.insert('capital_transactions', transaction);
    } catch (e) {
      print('❌ Error inserting capital transaction: $e');
      return -1;
    }
  }

  Future<int> deleteCapitalTransaction(int id) async {
    try {
      final db = await database;
      return await db.delete('capital_transactions', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error deleting capital transaction: $e');
      return -1;
    }
  }

  // ============ SARAFI ACCOUNTS ============
  Future<List<Map<String, dynamic>>> getSarafiAccounts() async {
    try {
      final db = await database;
      return await db.query('sarafi_accounts', orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting sarafi accounts: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSarafiAccountByNumber(String accountNumber) async {
    try {
      final db = await database;
      final result = await db.query('sarafi_accounts', where: 'account_number = ?', whereArgs: [accountNumber], limit: 1);
      if (result.isNotEmpty) return result.first;
      return null;
    } catch (e) {
      print('❌ Error getting sarafi account by number: $e');
      return null;
    }
  }

  Future<int> insertSarafiAccount(Map<String, dynamic> account) async {
    try {
      final db = await database;
      return await db.insert('sarafi_accounts', account);
    } catch (e) {
      print('❌ Error inserting sarafi account: $e');
      return -1;
    }
  }

  Future<int> deleteSarafiAccount(int id) async {
    try {
      final db = await database;
      return await db.delete('sarafi_accounts', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error deleting sarafi account: $e');
      return -1;
    }
  }

  Future<int> updateSarafiAccountBalance(int id, double currentUsdBalance) async {
    try {
      final db = await database;
      return await db.update('sarafi_accounts', {'current_usd_balance': currentUsdBalance}, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error updating sarafi account balance: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getSarafiTransactions() async {
    try {
      final db = await database;
      return await db.query('sarafi_transactions', orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting sarafi transactions: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSarafiTransactionsByAccount(int accountId) async {
    try {
      final db = await database;
      return await db.query(
        'sarafi_transactions',
        where: 'account_id = ?',
        whereArgs: [accountId],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      print('❌ Error getting sarafi transactions by account: $e');
      return [];
    }
  }

  Future<int> insertSarafiTransaction(Map<String, dynamic> transaction) async {
    try {
      final db = await database;
      await _repairSarafiTransactionsTable(db);
      return await db.insert('sarafi_transactions', transaction);
    } catch (e) {
      print('❌ Error inserting sarafi transaction: $e');
      return -1;
    }
  }

  Future<int> deleteSarafiTransaction(int id) async {
    try {
      final db = await database;
      return await db.delete('sarafi_transactions', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error deleting sarafi transaction: $e');
      return -1;
    }
  }

  // ============ RAW MATERIALS ============
  Future<List<Map<String, dynamic>>> getRawMaterials() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT raw_materials.*, 
          suppliers.name AS supplier_name,
          suppliers.phone AS supplier_phone,
          suppliers.email AS supplier_email,
          suppliers.address AS supplier_address
        FROM raw_materials
        LEFT JOIN suppliers ON raw_materials.supplier_id = suppliers.id
        ORDER BY raw_materials.created_at DESC, raw_materials.id DESC
      ''');
      print('📦 Raw materials fetched: ${result.length}');
      if (result.isNotEmpty) {
        print('📦 First material keys: ${result.first.keys}');
      }
      return result;
    } catch (e) {
      print('❌ Error getting raw materials: $e');
      return [];
    }
  }

  Future<int> insertRawMaterial(Map<String, dynamic> material) async {
    try {
      final db = await database;
      print('📦 Inserting: $material');
      return await db.insert('raw_materials', material);
    } catch (e) {
      print('❌ Error inserting raw material: $e');
      return -1;
    }
  }

  Future<int> updateRawMaterial(int id, Map<String, dynamic> material) async {
    try {
      final db = await database;
      return await db.update(
        'raw_materials',
        material,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Error updating raw material: $e');
      return -1;
    }
  }

  Future<int> deleteRawMaterial(int id) async {
    try {
      final db = await database;
      
      print('🔄 Deleting raw material ID: $id with all dependencies');
      
      await db.execute('BEGIN TRANSACTION');
      
      try {
        final loans = await db.query(
          'supplier_loans',
          where: 'raw_material_id = ?',
          whereArgs: [id],
        );
        
        for (var loan in loans) {
          await db.delete(
            'supplier_loan_payments',
            where: 'loan_id = ?',
            whereArgs: [loan['id']],
          );
          print('  ✅ Deleted payments for loan ${loan['id']}');
        }
        
        if (loans.isNotEmpty) {
          await db.delete(
            'supplier_loans',
            where: 'raw_material_id = ?',
            whereArgs: [id],
          );
          print('  ✅ Deleted ${loans.length} supplier loans');
        }
        
        final result = await db.delete(
          'raw_materials',
          where: 'id = ?',
          whereArgs: [id],
        );
        
        await db.execute('COMMIT');
        
        print('✅ Raw material $id deleted successfully');
        return result;
        
      } catch (e) {
        await db.execute('ROLLBACK');
        print('❌ Transaction rolled back: $e');
        return -1;
      }
      
    } catch (e) {
      print('❌ Error deleting raw material: $e');
      return -1;
    }
  }

  // ============ DAILY EXPENSES ============
  Future<List<Map<String, dynamic>>> getDailyExpenses() async {
    try {
      final db = await database;
      return await db.query('daily_expenses', orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting daily expenses: $e');
      return [];
    }
  }

  Future<int> insertDailyExpense(Map<String, dynamic> expense) async {
    try {
      final db = await database;
      
      if (expense['registration_number'] == null || 
          expense['registration_number'].toString().trim().isEmpty) {
        print('❌ registration_number is required');
        return -1;
      }
      
      expense['date_en'] = expense['date_en'] ?? PersianDateConverter.getEnglishDate(DateTime.now());
      
      try {
        final price = double.tryParse(expense['price']?.toString() ?? '0') ?? 0.0;
        final rate = double.tryParse(expense['exchange_rate']?.toString() ?? '0') ?? 0.0;
        expense['usd_equivalent'] = (price * rate).round();
      } catch (_) {}

      final filtered = await _filterMapForTableColumns(db, 'daily_expenses', expense);
      if (filtered.isEmpty) {
        print('⚠️ insertDailyExpense filtered empty - daily_expenses table may not exist or payload had no valid columns');
        return -1;
      }
      return await db.insert('daily_expenses', filtered);
    } catch (e) {
      print('❌ Error inserting daily expense: $e');
      return -1;
    }
  }

  Future<int> updateDailyExpense(int id, Map<String, dynamic> expense) async {
    try {
      final db = await database;
      final filtered = await _filterMapForTableColumns(db, 'daily_expenses', expense);
      if (filtered.isEmpty) {
        print('⚠️ updateDailyExpense filtered empty - daily_expenses table may not exist or payload had no valid columns');
        return -1;
      }
      return await db.update('daily_expenses', filtered, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error updating daily expense: $e');
      return -1;
    }
  }

  Future<int> deleteDailyExpense(int id) async {
    try {
      final db = await database;
      return await db.delete('daily_expenses', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error deleting daily expense: $e');
      return -1;
    }
  }

  // ============ WASTE / MATERIAL LOSSES ============
  Future<List<Map<String, dynamic>>> getWasteRecords() async {
    try {
      final db = await database;
      return await db.query('waste_material_losses', orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting waste records: $e');
      return [];
    }
  }

  Future<int> getNextWasteInvoiceNumber() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT MAX(CAST(invoice_number AS INTEGER)) AS max_invoice FROM waste_material_losses');
      final maxInvoice = result.isNotEmpty ? result.first['max_invoice'] : null;
      final currentValue = maxInvoice is int ? maxInvoice : int.tryParse(maxInvoice?.toString() ?? '') ?? 9999;
      return currentValue + 1;
    } catch (e) {
      print('❌ Error getting next waste invoice number: $e');
      return 10000;
    }
  }

  Future<int> insertWasteRecord(Map<String, dynamic> waste) async {
    try {
      final db = await database;
      if (waste['invoice_number'] == null || waste['invoice_number'].toString().trim().isEmpty) {
        final next = await getNextWasteInvoiceNumber();
        waste['invoice_number'] = next.toString().padLeft(5, '0');
      }
      waste['date_en'] = waste['date_en'] ?? PersianDateConverter.getEnglishDate(DateTime.now());
      final value = double.tryParse(waste['value']?.toString() ?? '0') ?? 0.0;
      final rate = double.tryParse(waste['exchange_rate']?.toString() ?? '0') ?? 0.0;
      waste['afn_equivalent'] = (value * rate).round();
      final filtered = await _filterMapForTableColumns(db, 'waste_material_losses', waste);
      if (filtered.isEmpty) {
        return -1;
      }
      return await db.insert('waste_material_losses', filtered);
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed') || e.toString().contains('constraint failed')) {
        try {
          waste['invoice_number'] = (await getNextWasteInvoiceNumber()).toString().padLeft(5, '0');
          final db = await database;
          final filtered = await _filterMapForTableColumns(db, 'waste_material_losses', waste);
          if (filtered.isEmpty) {
            return -1;
          }
          return await db.insert('waste_material_losses', filtered);
        } catch (retryError) {
          print('❌ Retry insert waste record failed: $retryError');
          return -1;
        }
      }
      print('❌ Error inserting waste record: $e');
      return -1;
    }
  }

  Future<int> updateWasteRecord(int id, Map<String, dynamic> waste) async {
    try {
      final db = await database;
      final value = double.tryParse(waste['value']?.toString() ?? '0') ?? 0.0;
      final rate = double.tryParse(waste['exchange_rate']?.toString() ?? '0') ?? 0.0;
      waste['afn_equivalent'] = (value * rate).round();
      final filtered = await _filterMapForTableColumns(db, 'waste_material_losses', waste);
      if (filtered.isEmpty) {
        return -1;
      }
      return await db.update('waste_material_losses', filtered, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error updating waste record: $e');
      return -1;
    }
  }

  Future<int> deleteWasteRecord(int id) async {
    try {
      final db = await database;
      return await db.delete('waste_material_losses', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error deleting waste record: $e');
      return -1;
    }
  }

  // ============ RESET ============
  Future<void> resetDatabase() async {
    try {
      init();
      final directory = await getApplicationDocumentsDirectory();
      final path = join(directory.path, 'victor_pipe.db');
      await deleteDatabase(path);
      _database = null;
      await database;
      print('✅ Database reset successfully!');
    } catch (e) {
      print('❌ Error resetting database: $e');
    }
  }

  // ============ PRODUCT STOCK (TOTAL WEIGHT) ============
  Future<Map<String, dynamic>> getTotalProductStock() async {
    try {
      final db = await database;
      
      final products = await db.query('produced_products');
      
      double totalKg = 0;
      double totalTons = 0;
      Map<String, double> unitBreakdown = {};
      
      for (var product in products) {
        String unit = product['unit']?.toString() ?? '';
        double weight = double.tryParse(product['remaining_stock']?.toString() ?? '0') ?? 0;
        if (weight == 0) {
          weight = double.tryParse(product['total_weight']?.toString() ?? '0') ?? 0;
        }
        
        if (_isWeightUnit(unit)) {
          if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
            totalKg += weight;
            totalTons += weight / 1000;
          } else if (unit == 'تن' || unit == 'ton' || unit == 'Ton') {
            totalKg += weight * 1000;
            totalTons += weight;
          }
        }
        
        unitBreakdown[unit] = (unitBreakdown[unit] ?? 0) + weight;
      }
      
      return {
        'total_kg': totalKg,
        'total_tons': totalTons,
        'total_tons_display': '${totalTons.toStringAsFixed(totalTons % 1 == 0 ? 0 : 2)} تن',
        'total_kg_display': '${totalKg.toStringAsFixed(totalKg % 1 == 0 ? 0 : 0)} کیلوگرم',
        'unit_breakdown': unitBreakdown,
        'product_count': products.length,
      };
    } catch (e) {
      print('❌ Error getting total product stock: $e');
      return {
        'total_kg': 0,
        'total_tons': 0,
        'total_tons_display': '0 تن',
        'total_kg_display': '0 کیلوگرم',
        'unit_breakdown': {},
        'product_count': 0,
      };
    }
  }

  bool _isWeightUnit(String unit) {
    return unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg' || 
           unit == 'تن' || unit == 'ton' || unit == 'Ton';
  }
}