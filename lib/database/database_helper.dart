import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'; // To find the right folder on Android/iOS

class DatabaseHelper {
  // Singleton pattern: ensures we only have one class instance
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Get the safe directory for storing data
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'subslayer.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE subscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        currency TEXT NOT NULL,
        renewalDate TEXT NOT NULL
      )
    ''');
  }

  // --- Helper Methods ---

  Future<int> addSubscription(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('subscriptions', row);
  }

  Future<List<Map<String, dynamic>>> getSubscriptions() async {
    Database db = await database;
    return await db.query('subscriptions', orderBy: 'renewalDate ASC');
  }

  Future<void> deleteAll() async {
    Database db = await database;
    await db.delete('subscriptions');
  }
}
