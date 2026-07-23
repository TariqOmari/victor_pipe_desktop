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
        version: 6, // ← CHANGED TO VERSION 6!
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
        version: 6, // ← CHANGED TO VERSION 6!
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
          print('✅ Added location column!');
        } catch (e) {
          print('⚠️ location column already exists or error: $e');
        }
        
        try {
          await db.execute('ALTER TABLE raw_materials ADD COLUMN material_type TEXT');
          print('✅ Added material_type column!');
        } catch (e) {
          print('⚠️ material_type column already exists or error: $e');
        }
        
        print('✅ Database upgraded to version 4 successfully!');
      }

      if (oldVersion < 5) {
        try {
          await db.execute('ALTER TABLE raw_materials ADD COLUMN date TEXT');
          print('✅ Added date column!');
        } catch (e) { print('⚠️ date column: $e'); }
        
        try {
          await db.execute('ALTER TABLE raw_materials ADD COLUMN unit TEXT');
          print('✅ Added unit column!');
        } catch (e) { print('⚠️ unit column: $e'); }
        
        try {
          await db.execute('ALTER TABLE raw_materials ADD COLUMN unit_price TEXT');
          print('✅ Added unit_price column!');
        } catch (e) { print('⚠️ unit_price column: $e'); }
        
        try {
          await db.execute('ALTER TABLE raw_materials ADD COLUMN product TEXT');
          print('✅ Added product column!');
        } catch (e) { print('⚠️ product column: $e'); }
        
        try {
          await db.execute('ALTER TABLE raw_materials ADD COLUMN commission TEXT');
          print('✅ Added commission column!');
        } catch (e) { print('⚠️ commission column: $e'); }
        
        try {
          await db.execute('ALTER TABLE raw_materials ADD COLUMN transfer_cost TEXT');
          print('✅ Added transfer_cost column!');
        } catch (e) { print('⚠️ transfer_cost column: $e'); }
        
        try {
          await db.execute('ALTER TABLE raw_materials ADD COLUMN miscellaneous TEXT');
          print('✅ Added miscellaneous column!');
        } catch (e) { print('⚠️ miscellaneous column: $e'); }
        
        try {
          await db.execute('ALTER TABLE raw_materials ADD COLUMN final_price TEXT');
          print('✅ Added final_price column!');
        } catch (e) { print('⚠️ final_price column: $e'); }
        
        print('✅ Database upgraded to version 5 successfully!');
      }

      // ★★★ NEW: Version 6 - Add غرفه داری and بارچلانی ★★★
      if (oldVersion < 6) {
        try {
          await db.execute('ALTER TABLE raw_materials ADD COLUMN ghurfedari TEXT');
          print('✅ Added غرفه داری column!');
        } catch (e) { print('⚠️ ghurfedari column: $e'); }
        
        try {
          await db.execute('ALTER TABLE raw_materials ADD COLUMN barchalani TEXT');
          print('✅ Added بارچلانی column!');
        } catch (e) { print('⚠️ barchalani column: $e'); }
        
        print('✅ Database upgraded to version 6 successfully!');
      }
      
      print('✅ Database upgraded successfully!');
    } catch (e) {
      print('❌ Error upgrading database: $e');
      rethrow;
    }
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