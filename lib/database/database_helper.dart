import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

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
    } catch (e) {
      print('❌ Error ensuring sell loan tables: $e');
      rethrow;
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
        version: 17,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          print('✅ Database opened successfully!');
          await _ensureProducedProductsTable(db);
          await _ensureCapitalTables(db);
          await _ensureCustomerCompanyTables(db);
          await _ensureSalesInvoiceTable(db);
          await _ensureSellLoanTables(db);
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
        version: 17,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          print('✅ Database opened successfully (fallback)!');
          await _ensureProducedProductsTable(db);
          await _ensureCapitalTables(db);
          await _ensureCustomerCompanyTables(db);
          await _ensureSalesInvoiceTable(db);
          await _ensureSellLoanTables(db);
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

      // ★★★ VERSION 11: ADD date_en COLUMN ★★★
      if (oldVersion < 11) {
        try {
          await db.execute('ALTER TABLE raw_materials ADD COLUMN date_en TEXT');
          print('✅ Added date_en column to raw_materials table');
        } catch (e) {
          print('⚠️ Error adding date_en: $e');
        }
        print('✅ Database upgraded to version 11!');
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
          print('✅ Added price_rate column to sales_invoices table');
        } catch (e) {
          print('⚠️ Error adding price_rate column (may already exist): $e');
        }
        print('✅ Database upgraded to version 17!');
      }
      
      print('✅ Database upgraded successfully!');
    } catch (e) {
      print('❌ Error upgrading database: $e');
      rethrow;
    }
  }

  Future<void> _ensureProducedProductsTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS produced_products(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_name TEXT NOT NULL,
          production_type TEXT,
          loading TEXT,
          thickness TEXT,
          length TEXT,
          quantity INTEGER,
          weight TEXT,
          unit TEXT,
          production_date TEXT,
          production_date_en TEXT,
          status TEXT,
          batch TEXT,
          description TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      try {
        await db.execute('ALTER TABLE produced_products ADD COLUMN loading TEXT');
      } catch (e) {
        print('⚠️ loading column already exists or could not be added: $e');
      }

      try {
        await db.execute('ALTER TABLE produced_products ADD COLUMN production_type TEXT');
      } catch (e) {
        print('⚠️ production_type column already exists or could not be added: $e');
      }

      try {
        await db.execute('ALTER TABLE produced_products ADD COLUMN production_date_en TEXT');
      } catch (e) {
        print('⚠️ production_date_en column already exists or could not be added: $e');
      }
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
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
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
        final_price TEXT,
        ghurfedari TEXT,
        barchalani TEXT,
        purchase_type TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE produced_products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_name TEXT NOT NULL,
        production_type TEXT,
        loading TEXT,
        thickness TEXT,
        length TEXT,
        quantity INTEGER,
        weight TEXT,
        unit TEXT,
        production_date TEXT,
        production_date_en TEXT,
        status TEXT,
        batch TEXT,
        description TEXT,
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

    await _ensureSalesInvoiceTable(db);
    await _ensureSellLoanTables(db);
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
  Future<List<Map<String, dynamic>>> getSalesInvoices() async {
    try {
      final db = await database;
      return await db.query('sales_invoices', orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting sales invoices: $e');
      return [];
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

  // ============ SELL LOANS ============
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

  Future<int> updateSellLoanPaid(int loanId, double paidAmount, double remainingAmount) async {
    try {
      final db = await database;
      return await db.update('sell_loans', {'paid_amount': paidAmount, 'remaining_amount': remainingAmount}, where: 'id = ?', whereArgs: [loanId]);
    } catch (e) {
      print('❌ Error updating sell loan paid/remaining: $e');
      return -1;
    }
  }

  // ============ PRODUCED PRODUCTS ============
  Future<List<Map<String, dynamic>>> getProducedProducts() async {
    try {
      final db = await database;
      return await db.query('produced_products', orderBy: 'created_at DESC');
    } catch (e) {
      print('❌ Error getting produced products: $e');
      return [];
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

  Future<int> insertProducedProduct(Map<String, dynamic> product) async {
    try {
      final db = await database;
      return await db.insert('produced_products', product);
    } catch (e) {
      print('❌ Error inserting produced product: $e');
      return -1;
    }
  }

  Future<int> updateProducedProduct(int id, Map<String, dynamic> product) async {
    try {
      final db = await database;
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

  // ============ RAW MATERIALS ============
  Future<List<Map<String, dynamic>>> getRawMaterials() async {
    try {
      final db = await database;
      final result = await db.query('raw_materials', orderBy: 'name ASC');
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
      return await db.delete(
        'raw_materials',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Error deleting raw material: $e');
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
}