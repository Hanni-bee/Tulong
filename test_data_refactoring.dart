import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'lib/services/sqlite_service.dart';
import 'lib/services/unified_data_service.dart';

void main() {
  group('Data Refactoring Tests', () {
    late SQLiteService sqliteService;
    late UnifiedDataService unifiedDataService;

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      sqliteService = SQLiteService();
      unifiedDataService = UnifiedDataService();
    });

    tearDown(() async {
      await sqliteService.close();
    });

    test('SQLite schema has correct snake_case fields', () async {
      final db = await sqliteService.database;
      
      // Test that the users table has the correct snake_case fields
      final result = await db.rawQuery("PRAGMA table_info(users)");
      final columnNames = result.map((column) => column['name'] as String).toList();
      
      expect(columnNames, contains('first_name'));
      expect(columnNames, contains('last_name'));
      expect(columnNames, contains('email'));
      expect(columnNames, contains('zip_code'));
      expect(columnNames, contains('account_status'));
      expect(columnNames, contains('is_google_auth'));
      expect(columnNames, contains('address_setup_completed'));
    });

    test('UnifiedDataService creates user with correct data format', () async {
      final userData = await unifiedDataService.createUser(
        email: 'test@example.com',
        password: 'password123',
        firstName: 'John',
        lastName: 'Doe',
        street: '123 Main St',
        region: 'NCR',
        city: 'Manila',
        barangay: 'Ermita',
        zipCode: '1000',
      );

      expect(userData, isNotNull);
      expect(userData!['email'], equals('test@example.com'));
      expect(userData['first_name'], equals('John'));
      expect(userData['last_name'], equals('Doe'));
      expect(userData['street'], equals('123 Main St'));
      expect(userData['account_status'], equals('active'));
      expect(userData['is_google_auth'], equals(0));
      expect(userData['address_setup_completed'], equals(0));
    });

    test('UnifiedDataService authenticates user correctly', () async {
      // First create a user
      await unifiedDataService.createUser(
        email: 'auth@example.com',
        password: 'password123',
        firstName: 'Jane',
        lastName: 'Smith',
      );

      // Then authenticate
      final authResult = await unifiedDataService.authenticateUser(
        'auth@example.com',
        'password123',
      );

      expect(authResult, isNotNull);
      expect(authResult!['email'], equals('auth@example.com'));
      expect(authResult['first_name'], equals('Jane'));
      expect(authResult['last_name'], equals('Smith'));
    });

    test('UnifiedDataService updates user profile correctly', () async {
      // Create user first
      await unifiedDataService.createUser(
        email: 'update@example.com',
        password: 'password123',
        firstName: 'Original',
        lastName: 'Name',
      );

      // Update profile
      final success = await unifiedDataService.updateUserProfile(
        email: 'update@example.com',
        firstName: 'Updated',
        lastName: 'Name',
        street: '456 New St',
        region: 'NCR',
        city: 'Quezon City',
        barangay: 'Diliman',
      );

      expect(success, isTrue);

      // Verify update
      final updatedUser = await unifiedDataService.getUserByEmail('update@example.com');
      expect(updatedUser, isNotNull);
      expect(updatedUser!['first_name'], equals('Updated'));
      expect(updatedUser['street'], equals('456 New St'));
      expect(updatedUser['city'], equals('Quezon City'));
    });

    test('UnifiedDataService handles password updates', () async {
      // Create user first
      await unifiedDataService.createUser(
        email: 'password@example.com',
        password: 'oldpassword',
        firstName: 'Test',
        lastName: 'User',
      );

      // Update password
      final success = await unifiedDataService.updatePassword(
        'password@example.com',
        'newpassword',
      );

      expect(success, isTrue);

      // Verify old password doesn't work
      final oldAuthResult = await unifiedDataService.authenticateUser(
        'password@example.com',
        'oldpassword',
      );
      expect(oldAuthResult, isNull);

      // Verify new password works
      final newAuthResult = await unifiedDataService.authenticateUser(
        'password@example.com',
        'newpassword',
      );
      expect(newAuthResult, isNotNull);
    });

    test('UnifiedDataService marks address setup as completed', () async {
      // Create user first
      await unifiedDataService.createUser(
        email: 'address@example.com',
        password: 'password123',
        firstName: 'Address',
        lastName: 'Test',
      );

      // Mark address setup as completed
      final success = await unifiedDataService.markAddressSetupCompleted('address@example.com');
      expect(success, isTrue);

      // Verify the flag is set
      final user = await unifiedDataService.getUserByEmail('address@example.com');
      expect(user, isNotNull);
      expect(user!['address_setup_completed'], equals(1));
    });
  });
}
