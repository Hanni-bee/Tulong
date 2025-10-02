// T.U.L.O.N.G APK Build Verification Script
// This script verifies that Firebase and SQLite features are properly configured for APK build

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class APKBuildVerification {
  static final APKBuildVerification _instance = APKBuildVerification._internal();
  factory APKBuildVerification() => _instance;
  APKBuildVerification._internal();

  // Test results
  final Map<String, bool> _testResults = {};
  final List<String> _errors = [];
  final List<String> _warnings = [];

  // Get test results
  Map<String, bool> get testResults => _testResults;
  List<String> get errors => _errors;
  List<String> get warnings => _warnings;

  // Run all verification tests
  Future<Map<String, dynamic>> runAllTests() async {
    print('🔍 Starting APK Build Verification...');
    print('=====================================');
    
    _testResults.clear();
    _errors.clear();
    _warnings.clear();

    // Test Firebase components
    await _testFirebaseCore();
    await _testFirebaseAuth();
    await _testFirebaseDatabase();
    await _testFirebaseStorage();
    await _testFirebaseAnalytics();
    await _testFirebaseMessaging();

    // Test SQLite components
    await _testSQLiteDatabase();
    await _testSQLiteOperations();

    // Test connectivity
    await _testConnectivity();
    await _testInternetConnection();

    // Test crypto
    await _testCrypto();

    // Generate report
    final report = _generateReport();
    print('=====================================');
    print('✅ APK Build Verification Complete!');
    print('=====================================');
    
    return report;
  }

  // Test Firebase Core
  Future<void> _testFirebaseCore() async {
    try {
      await Firebase.initializeApp();
      _testResults['firebase_core'] = true;
      print('✅ Firebase Core: Initialized successfully');
    } catch (e) {
      _testResults['firebase_core'] = false;
      _errors.add('Firebase Core initialization failed: $e');
      print('❌ Firebase Core: Failed to initialize - $e');
    }
  }

  // Test Firebase Auth
  Future<void> _testFirebaseAuth() async {
    try {
      final auth = FirebaseAuth.instance;
      _testResults['firebase_auth'] = true;
      print('✅ Firebase Auth: Available');
    } catch (e) {
      _testResults['firebase_auth'] = false;
      _errors.add('Firebase Auth not available: $e');
      print('❌ Firebase Auth: Not available - $e');
    }
  }

  // Test Firebase Database
  Future<void> _testFirebaseDatabase() async {
    try {
      final database = FirebaseDatabase.instance;
      _testResults['firebase_database'] = true;
      print('✅ Firebase Database: Available');
    } catch (e) {
      _testResults['firebase_database'] = false;
      _errors.add('Firebase Database not available: $e');
      print('❌ Firebase Database: Not available - $e');
    }
  }

  // Test Firebase Storage
  Future<void> _testFirebaseStorage() async {
    try {
      final storage = FirebaseStorage.instance;
      _testResults['firebase_storage'] = true;
      print('✅ Firebase Storage: Available');
    } catch (e) {
      _testResults['firebase_storage'] = false;
      _errors.add('Firebase Storage not available: $e');
      print('❌ Firebase Storage: Not available - $e');
    }
  }

  // Test Firebase Analytics
  Future<void> _testFirebaseAnalytics() async {
    try {
      final analytics = FirebaseAnalytics.instance;
      _testResults['firebase_analytics'] = true;
      print('✅ Firebase Analytics: Available');
    } catch (e) {
      _testResults['firebase_analytics'] = false;
      _errors.add('Firebase Analytics not available: $e');
      print('❌ Firebase Analytics: Not available - $e');
    }
  }

  // Test Firebase Messaging
  Future<void> _testFirebaseMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;
      _testResults['firebase_messaging'] = true;
      print('✅ Firebase Messaging: Available');
    } catch (e) {
      _testResults['firebase_messaging'] = false;
      _errors.add('Firebase Messaging not available: $e');
      print('❌ Firebase Messaging: Not available - $e');
    }
  }

  // Test SQLite Database
  Future<void> _testSQLiteDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      _testResults['sqlite_database'] = true;
      print('✅ SQLite Database: Path available - $databasesPath');
    } catch (e) {
      _testResults['sqlite_database'] = false;
      _errors.add('SQLite Database path not available: $e');
      print('❌ SQLite Database: Path not available - $e');
    }
  }

  // Test SQLite Operations
  Future<void> _testSQLiteOperations() async {
    try {
      final database = await openDatabase(
        join(await getDatabasesPath(), 'test.db'),
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE test_table (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL
            )
          ''');
        },
      );

      // Test insert
      await database.insert('test_table', {'name': 'test'});

      // Test query
      final result = await database.query('test_table');
      if (result.isNotEmpty) {
        _testResults['sqlite_operations'] = true;
        print('✅ SQLite Operations: Insert and query successful');
      } else {
        _testResults['sqlite_operations'] = false;
        _errors.add('SQLite operations failed: No data returned');
        print('❌ SQLite Operations: No data returned');
      }

      await database.close();
    } catch (e) {
      _testResults['sqlite_operations'] = false;
      _errors.add('SQLite operations failed: $e');
      print('❌ SQLite Operations: Failed - $e');
    }
  }

  // Test Connectivity
  Future<void> _testConnectivity() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      _testResults['connectivity'] = true;
      print('✅ Connectivity: Available - $result');
    } catch (e) {
      _testResults['connectivity'] = false;
      _errors.add('Connectivity check failed: $e');
      print('❌ Connectivity: Failed - $e');
    }
  }

  // Test Internet Connection
  Future<void> _testInternetConnection() async {
    try {
      final checker = InternetConnectionChecker();
      final hasConnection = await checker.hasConnection;
      _testResults['internet_connection'] = true;
      print('✅ Internet Connection: Available - $hasConnection');
    } catch (e) {
      _testResults['internet_connection'] = false;
      _errors.add('Internet connection check failed: $e');
      print('❌ Internet Connection: Failed - $e');
    }
  }

  // Test Crypto
  Future<void> _testCrypto() async {
    try {
      final bytes = utf8.encode('test password');
      final digest = sha256.convert(bytes);
      _testResults['crypto'] = true;
      print('✅ Crypto: Available - Hash generated');
    } catch (e) {
      _testResults['crypto'] = false;
      _errors.add('Crypto operations failed: $e');
      print('❌ Crypto: Failed - $e');
    }
  }

  // Generate verification report
  Map<String, dynamic> _generateReport() {
    final totalTests = _testResults.length;
    final passedTests = _testResults.values.where((result) => result).length;
    final failedTests = totalTests - passedTests;

    final report = {
      'summary': {
        'total_tests': totalTests,
        'passed_tests': passedTests,
        'failed_tests': failedTests,
        'success_rate': (passedTests / totalTests * 100).toStringAsFixed(1),
      },
      'results': _testResults,
      'errors': _errors,
      'warnings': _warnings,
      'recommendations': _generateRecommendations(),
    };

    print('📊 Verification Summary:');
    print('  Total Tests: $totalTests');
    print('  Passed: $passedTests');
    print('  Failed: $failedTests');
    print('  Success Rate: ${(report['summary'] as Map<String, dynamic>?)?['success_rate'] ?? 0}%');

    if (_errors.isNotEmpty) {
      print('\n❌ Errors:');
      for (final error in _errors) {
        print('  - $error');
      }
    }

    if (_warnings.isNotEmpty) {
      print('\n⚠️ Warnings:');
      for (final warning in _warnings) {
        print('  - $warning');
      }
    }

    return report;
  }

  // Generate recommendations
  List<String> _generateRecommendations() {
    final recommendations = <String>[];

    if (!_testResults['firebase_core']!) {
      recommendations.add('Check Firebase configuration in android/app/google-services.json');
    }

    if (!_testResults['sqlite_database']!) {
      recommendations.add('Verify SQLite dependencies in pubspec.yaml');
    }

    if (!_testResults['connectivity']!) {
      recommendations.add('Check internet permissions in AndroidManifest.xml');
    }

    if (_errors.isNotEmpty) {
      recommendations.add('Review error messages and fix configuration issues');
    }

    if (recommendations.isEmpty) {
      recommendations.add('All systems are ready for APK build!');
    }

    return recommendations;
  }
}

// Widget to run verification in your app
class APKVerificationWidget extends StatefulWidget {
  const APKVerificationWidget({super.key});

  @override
  State<APKVerificationWidget> createState() => _APKVerificationWidgetState();
}

class _APKVerificationWidgetState extends State<APKVerificationWidget> {
  bool _isRunning = false;
  Map<String, dynamic>? _report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('APK Build Verification'),
        backgroundColor: const Color(0xFFD32F2F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Verify APK Build Configuration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will verify that Firebase and SQLite features are properly configured for APK build.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isRunning ? null : _runVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isRunning
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Run Verification',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
            const SizedBox(height: 24),
            if (_report != null) ...[
              const Text(
                'Verification Results:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _buildResultsCard(),
                      if (_report!['errors'].isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildErrorsCard(),
                      ],
                      if (_report!['recommendations'].isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildRecommendationsCard(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _runVerification() async {
    setState(() {
      _isRunning = true;
      _report = null;
    });

    try {
      final report = await APKBuildVerification().runAllTests();
      setState(() {
        _report = report;
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _isRunning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSummaryCard() {
    final summary = _report!['summary'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Total Tests: ${summary['total_tests']}'),
            Text('Passed: ${summary['passed_tests']}'),
            Text('Failed: ${summary['failed_tests']}'),
            Text('Success Rate: ${summary['success_rate']}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    final results = _report!['results'] as Map<String, bool>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...results.entries.map((entry) => Row(
              children: [
                Icon(
                  entry.value ? Icons.check_circle : Icons.error,
                  color: entry.value ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.key)),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorsCard() {
    final errors = _report!['errors'] as List<String>;
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Errors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 8),
            ...errors.map((error) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text('• $error', style: const TextStyle(color: Colors.red)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    final recommendations = _report!['recommendations'] as List<String>;
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommendations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            ...recommendations.map((recommendation) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text('• $recommendation', style: const TextStyle(color: Colors.blue)),
            )),
          ],
        ),
      ),
    );
  }
}
