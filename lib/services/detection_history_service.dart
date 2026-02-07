import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/storage_keys.dart';
import '../models/emergency_detection_result.dart';
import '../models/emergency_type.dart';

/// Service for storing and retrieving emergency detection history in SQLite
class DetectionHistoryService {
  static DetectionHistoryService? _instance;
  static DetectionHistoryService get instance => _instance ??= DetectionHistoryService._internal();
  
  DetectionHistoryService._internal();
  
  static Database? _database;
  static const String _databaseName = 'detection_history.db';
  static const int _databaseVersion = 2; // Incremented for user_uid migration
  static const String _tableName = 'detections';
  
  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  /// Initialize database
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateTable(db);
        }
      },
    );
  }
  
  /// Create table
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_uid TEXT NOT NULL,
        emergency_type TEXT NOT NULL,
        severity TEXT NOT NULL,
        confidence REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        image_path TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    
    // Create indexes for faster queries
    await db.execute('''
      CREATE INDEX idx_timestamp ON $_tableName(timestamp DESC)
    ''');
    await db.execute('''
      CREATE INDEX idx_user_uid ON $_tableName(user_uid)
    ''');
    await db.execute('''
      CREATE INDEX idx_user_timestamp ON $_tableName(user_uid, timestamp DESC)
    ''');
  }
  
  /// Migrate existing table to add user_uid column
  Future<void> _migrateTable(Database db) async {
    try {
      // Check if user_uid column exists
      final tableInfo = await db.rawQuery('PRAGMA table_info($_tableName)');
      final hasUserUid = tableInfo.any((column) => column['name'] == 'user_uid');
      
      if (!hasUserUid) {
        // Add user_uid column
        await db.execute('ALTER TABLE $_tableName ADD COLUMN user_uid TEXT');
        // Update existing records with default UID (if available from SharedPreferences)
        final prefs = await SharedPreferences.getInstance();
        final defaultUid = prefs.getString(StorageKeys.sessionUid) ?? 'unknown';
        await db.update(
          _tableName,
          {'user_uid': defaultUid},
          where: 'user_uid IS NULL',
        );
        // Create indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_user_uid ON $_tableName(user_uid)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_user_timestamp ON $_tableName(user_uid, timestamp DESC)');
      }
    } catch (e) {
      debugPrint('Migration error: $e');
    }
  }
  
  /// Save detection result to database with user UID
  Future<int> saveDetection(EmergencyDetectionResult result) async {
    final db = await database;
    
    // Get user UID from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userUid = prefs.getString(StorageKeys.sessionUid) ?? 'unknown';
    
    // Ensure migration is applied
    await _migrateTable(db);
    
    final id = await db.insert(
      _tableName,
      {
        'user_uid': userUid,
        'emergency_type': result.type.name,
        'severity': result.severity.name,
        'confidence': result.confidence,
        'timestamp': result.timestamp.millisecondsSinceEpoch,
        'image_path': result.imagePath,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
    
    // Update user's current status in SharedPreferences (enum names for consistency)
    final severityKey = result.severity.name;
    final typeKey = result.type.name;
    final ts = result.timestamp.millisecondsSinceEpoch;
    await prefs.setString(StorageKeys.userCurrentStatus, severityKey);
    await prefs.setString(StorageKeys.userCurrentEmergencyType, typeKey);
    await prefs.setInt(StorageKeys.userStatusLastUpdated, ts);
    if (kDebugMode) {
      debugPrint('📦 [SEVERITY] Saved to prefs: severity=$severityKey, emergencyType=$typeKey, ts=$ts');
    }
    return id;
  }
  
  /// Get current user's latest status
  Future<Map<String, dynamic>?> getCurrentUserStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userUid = prefs.getString(StorageKeys.sessionUid);
    
    if (userUid == null) return null;
    
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'user_uid = ?',
      whereArgs: [userUid],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    
    final map = maps.first;
    return {
      'emergency_type': map['emergency_type'],
      'severity': map['severity'],
      'confidence': map['confidence'],
      'timestamp': map['timestamp'],
      'last_updated': map['timestamp'],
    };
  }
  
  /// Get user's detection history
  Future<List<EmergencyDetectionResult>> getUserDetections({int? limit}) async {
    final prefs = await SharedPreferences.getInstance();
    final userUid = prefs.getString(StorageKeys.sessionUid);
    
    if (userUid == null) return [];
    
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'user_uid = ?',
      whereArgs: [userUid],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return maps.map((map) => _mapToResult(map)).toList();
  }
  
  /// Get all detections, ordered by most recent first
  Future<List<EmergencyDetectionResult>> getAllDetections({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return maps.map((map) => _mapToResult(map)).toList();
  }
  
  /// Get recent detections for current user (default behavior)
  Future<List<EmergencyDetectionResult>> getRecentDetections(int count) async {
    return await getUserDetections(limit: count);
  }
  
  /// Get detections by emergency type
  Future<List<EmergencyDetectionResult>> getDetectionsByType(EmergencyType type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'emergency_type = ?',
      whereArgs: [type.name],
      orderBy: 'timestamp DESC',
    );
    
    return maps.map((map) => _mapToResult(map)).toList();
  }
  
  
  /// Get detection count
  Future<int> getDetectionCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  /// Delete detection by ID
  Future<int> deleteDetection(int id) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// Clear all detections
  Future<int> clearAllDetections() async {
    final db = await database;
    return await db.delete(_tableName);
  }
  
  /// Convert database map to EmergencyDetectionResult (defensive: null/empty use enum defaults)
  EmergencyDetectionResult _mapToResult(Map<String, dynamic> map) {
    final typeStr = (map['emergency_type'] as String?)?.trim();
    final severityStr = (map['severity'] as String?)?.trim();
    final ts = map['timestamp'] as int?;
    return EmergencyDetectionResult(
      type: EmergencyType.fromString(typeStr?.isNotEmpty == true ? typeStr! : 'noEmergency'),
      severity: SeverityLevel.fromString(severityStr?.isNotEmpty == true ? severityStr! : 'medium'),
      confidence: ((map['confidence'] as num?)?.toDouble()) ?? 0.0,
      timestamp: ts != null && ts > 0
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : DateTime.now(),
      imagePath: map['image_path'] as String?,
    );
  }
  
  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
