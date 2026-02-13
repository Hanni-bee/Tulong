import 'dart:async';
import 'dart:convert';
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
  static const int _databaseVersion = 4; // v3: failure_reason, probability_breakdown; v4: detection_feedback
  static const String _tableName = 'detections';
  static const String _feedbackTableName = 'detection_feedback';
  
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
        if (oldVersion < 3) {
          await _migrateToV3(db);
        }
        if (oldVersion < 4) {
          await _migrateToV4(db);
        }
      },
    );
  }
  
  /// Create table (v3 schema includes failure_reason and probability_breakdown)
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
        created_at INTEGER NOT NULL,
        failure_reason TEXT,
        probability_breakdown TEXT
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
    await _createFeedbackTable(db);
  }

  Future<void> _createFeedbackTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_feedbackTableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        correct INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_feedback_key ON $_feedbackTableName(image_path, timestamp)
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

  /// Migrate to v3: add failure_reason and probability_breakdown columns
  Future<void> _migrateToV3(Database db) async {
    try {
      final tableInfo = await db.rawQuery('PRAGMA table_info($_tableName)');
      final hasFailureReason = tableInfo.any((c) => c['name'] == 'failure_reason');
      final hasProbabilityBreakdown = tableInfo.any((c) => c['name'] == 'probability_breakdown');
      if (!hasFailureReason) {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN failure_reason TEXT');
      }
      if (!hasProbabilityBreakdown) {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN probability_breakdown TEXT');
      }
    } catch (e) {
      debugPrint('Migration v3 error: $e');
    }
  }

  /// Migrate to v4: add detection_feedback table
  Future<void> _migrateToV4(Database db) async {
    await _createFeedbackTable(db);
  }

  /// Save user feedback for a detection (local only; for future tuning).
  Future<void> saveDetectionFeedback({
    required String? imagePath,
    required DateTime timestamp,
    required bool correct,
  }) async {
    if (imagePath == null || imagePath.isEmpty) return;
    final db = await database;
    await db.insert(
      _feedbackTableName,
      {
        'image_path': imagePath,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'correct': correct ? 1 : 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Whether feedback was already submitted for this detection.
  Future<bool> hasFeedbackForDetection({required String? imagePath, required DateTime timestamp}) async {
    if (imagePath == null || imagePath.isEmpty) return false;
    final db = await database;
    final list = await db.query(
      _feedbackTableName,
      where: 'image_path = ? AND timestamp = ?',
      whereArgs: [imagePath, timestamp.millisecondsSinceEpoch],
      limit: 1,
    );
    return list.isNotEmpty;
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
        'failure_reason': result.failureReason,
        'probability_breakdown': result.probabilityBreakdown != null && result.probabilityBreakdown!.isNotEmpty
            ? jsonEncode(result.probabilityBreakdown)
            : null,
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
  
  /// Parse probability_breakdown from DB (JSON string) to Map<String, double>
  Map<String, double>? _parseProbabilityBreakdown(dynamic value) {
    if (value == null) return null;
    if (value is! String) return null;
    try {
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      final out = <String, double>{};
      for (final e in decoded.entries) {
        final v = e.value;
        out[e.key] = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
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
      failureReason: map['failure_reason'] as String?,
      probabilityBreakdown: _parseProbabilityBreakdown(map['probability_breakdown']),
    );
  }
  
  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
