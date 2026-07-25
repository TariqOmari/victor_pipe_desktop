import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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
        version: 9,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) {
          print('✅ Database opened successfully!');
        },
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
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
        version: 9,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) {
          print('✅ Database opened successfully (fallback)!');
        },
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
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
      
      print('✅ Database upgraded successfully!');
    } catch (e) {
      print('❌ Error upgrading database: $e');
      rethrow;
    }
  }

  Future<void> _createTables(Database db) async {
    // Users table with profile_pic
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
        unit TEXT,
        unit_price TEXT,
        product TEXT,
        commission TEXT,
        transfer_cost TEXT,
        miscellaneous TEXT,
        final_price TEXT,
        ghurfedari TEXT,
        barchalani TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');
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