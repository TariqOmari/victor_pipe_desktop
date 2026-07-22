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

  // Initialize FFI for Windows desktop
  static void init() {
    if (!_initialized) {
      print('🔄 Initializing sqflite FFI...');
      // Initialize FFI for Windows
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _initialized = true;
      print('✅ sqflite FFI initialized!');
    }
  }

  Future<Database> get database async {
    try {
      // Make sure FFI is initialized
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
      // Get the documents directory for Windows
      final directory = await getApplicationDocumentsDirectory();
      final path = join(directory.path, 'victor_pipe.db');
      
      print('✅ Database path: $path');
      
      return await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onOpen: (db) {
          print('✅ Database opened successfully!');
        },
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
    } catch (e) {
      print('❌ Error with primary path: $e');
      // Try fallback path
      return await _initDatabaseFallback();
    }
  }

  // Fallback initialization using temp directory
  Future<Database> _initDatabaseFallback() async {
    try {
      final directory = await getTemporaryDirectory();
      final path = join(directory.path, 'victor_pipe.db');
      
      print('✅ Using fallback database path: $path');
      
      return await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
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
      
      // Users table
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

      // Create default admin user
      await db.insert('users', {
        'username': 'admin',
        'password': 'admin123',
        'full_name': 'مدیر سیستم',
        'email': 'admin@victorpipe.com',
        'role': 'admin',
      });
      
      print('✅ Admin user created successfully!');

      // Products table
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

      // Sample products
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
      
      print('✅ Sample products created successfully!');
      print('✅ Database created successfully!');
    } catch (e) {
      print('❌ Error creating database tables: $e');
      rethrow;
    }
  }

  // Check user credentials
  Future<Map<String, dynamic>?> loginUser(
      String username, String password) async {
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
      print('❌ Login failed - invalid credentials');
      return null;
    } catch (e) {
      print('❌ Login error: $e');
      return null;
    }
  }

  // Get all users
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final db = await database;
      return await db.query('users');
    } catch (e) {
      print('❌ Error getting users: $e');
      return [];
    }
  }

  // Get products
  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final db = await database;
      return await db.query('products');
    } catch (e) {
      print('❌ Error getting products: $e');
      return [];
    }
  }

  // Insert product
  Future<int> insertProduct(Map<String, dynamic> product) async {
    try {
      final db = await database;
      return await db.insert('products', product);
    } catch (e) {
      print('❌ Error inserting product: $e');
      return -1;
    }
  }

  // Update product
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

  // Delete product
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

  // Reset database (for debugging)
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