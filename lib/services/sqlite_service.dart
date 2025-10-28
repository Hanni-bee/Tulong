import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SQLiteService {
  static final SQLiteService _instance = SQLiteService._internal();
  factory SQLiteService() => _instance;
  SQLiteService._internal();

  static Database? _database;
  static const String _databaseName = 'tulong_offline.db';
  static const int _databaseVersion = 2;

  // Table names
  static const String _usersTable = 'users';
  static const String _messagesTable = 'messages';
  static const String _emergencyAlertsTable = 'emergency_alerts';
  static const String _syncQueueTable = 'sync_queue';

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Create tables
  Future<void> _onCreate(Database db, int version) async {
    // Users table - Updated with consistent snake_case naming
    await db.execute('''
      CREATE TABLE $_usersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_uid TEXT UNIQUE,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        phone TEXT,
        street TEXT,
        region TEXT,
        province TEXT,
        city TEXT,
        barangay TEXT,
        
        password TEXT,
        is_online INTEGER DEFAULT 0,
        account_status TEXT DEFAULT 'active',
        created_at INTEGER NOT NULL,
        last_seen INTEGER,
        is_synced INTEGER DEFAULT 0,
        sync_timestamp INTEGER,
        is_google_auth INTEGER DEFAULT 0,
        address_setup_completed INTEGER DEFAULT 0
      )
    ''');

    // Messages table
    await db.execute('''
      CREATE TABLE $_messagesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_key TEXT,
        chat_id TEXT NOT NULL,
        message TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        message_type TEXT DEFAULT 'text',
        image_url TEXT,
        is_synced INTEGER DEFAULT 0,
        sync_timestamp INTEGER
      )
    ''');

    // Emergency alerts table
    await db.execute('''
      CREATE TABLE $_emergencyAlertsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_key TEXT,
        message TEXT NOT NULL,
        location TEXT NOT NULL,
        user_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status TEXT DEFAULT 'active',
        is_synced INTEGER DEFAULT 0,
        sync_timestamp INTEGER
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE $_syncQueueTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_attempt INTEGER
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns to users table
      await db.execute('ALTER TABLE $_usersTable ADD COLUMN phone TEXT');
      await db.execute('ALTER TABLE $_usersTable ADD COLUMN street TEXT');
      await db.execute('ALTER TABLE $_usersTable ADD COLUMN province TEXT');
      await db.execute('ALTER TABLE $_usersTable ADD COLUMN account_status TEXT DEFAULT "active"');
      await db.execute('ALTER TABLE $_usersTable ADD COLUMN is_google_auth INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE $_usersTable ADD COLUMN address_setup_completed INTEGER DEFAULT 0');
      
      // Update existing records to have default values
      await db.execute('UPDATE $_usersTable SET account_status = "active" WHERE account_status IS NULL');
      await db.execute('UPDATE $_usersTable SET is_google_auth = 0 WHERE is_google_auth IS NULL');
      await db.execute('UPDATE $_usersTable SET address_setup_completed = 0 WHERE address_setup_completed IS NULL');
    }
  }

  // User operations
  Future<int> insertUser(Map<String, dynamic> userData) async {
    final db = await database;
    return await db.insert(_usersTable, userData);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query(_usersTable, orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final results = await db.query(
      _usersTable,
      where: 'email = ?',
      whereArgs: [email],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final results = await db.query(
      _usersTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateUser(int id, Map<String, dynamic> userData) async {
    final db = await database;
    return await db.update(
      _usersTable,
      userData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete(
      _usersTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Message operations
  Future<int> insertMessage(Map<String, dynamic> messageData) async {
    final db = await database;
    return await db.insert(_messagesTable, messageData);
  }

  Future<List<Map<String, dynamic>>> getMessagesByChatId(String chatId) async {
    final db = await database;
    return await db.query(
      _messagesTable,
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedMessages() async {
    final db = await database;
    return await db.query(
      _messagesTable,
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
  }

  // Emergency alerts operations
  Future<int> insertEmergencyAlert(Map<String, dynamic> alertData) async {
    final db = await database;
    return await db.insert(_emergencyAlertsTable, alertData);
  }

  Future<List<Map<String, dynamic>>> getAllEmergencyAlerts() async {
    final db = await database;
    return await db.query(
      _emergencyAlertsTable,
      orderBy: 'timestamp DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAlerts() async {
    final db = await database;
    return await db.query(
      _emergencyAlertsTable,
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
  }

  // Sync queue operations
  Future<int> addToSyncQueue({
    required String tableName,
    required int recordId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    return await db.insert(_syncQueueTable, {
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'data': data.toString(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
      'last_attempt': null,
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;
    return await db.query(
      _syncQueueTable,
      orderBy: 'created_at ASC',
    );
  }

  Future<int> removeFromSyncQueue(int id) async {
    final db = await database;
    return await db.delete(
      _syncQueueTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Mark records as synced
  Future<int> markUserAsSynced(int id, String firebaseUid) async {
    final db = await database;
    return await db.update(
      _usersTable,
      {
        'is_synced': 1,
        'firebase_uid': firebaseUid,
        'sync_timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markMessageAsSynced(int id, String firebaseKey) async {
    final db = await database;
    return await db.update(
      _messagesTable,
      {
        'is_synced': 1,
        'firebase_key': firebaseKey,
        'sync_timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAlertAsSynced(int id, String firebaseKey) async {
    final db = await database;
    return await db.update(
      _emergencyAlertsTable,
      {
        'is_synced': 1,
        'firebase_key': firebaseKey,
        'sync_timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get unsynced records
  Future<List<Map<String, dynamic>>> getUnsyncedUsers() async {
    final db = await database;
    return await db.query(
      _usersTable,
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  // Clear all data (for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(_usersTable);
    await db.delete(_messagesTable);
    await db.delete(_emergencyAlertsTable);
    await db.delete(_syncQueueTable);
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
