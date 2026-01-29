// Firebase Service - REMOVED (App is now offline-only)
// This file is kept as a stub to prevent compilation errors
// All Firebase functionality has been removed

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Stub methods to prevent compilation errors
  // All methods throw exceptions indicating Firebase is no longer available
  
  String hashPassword(String password) {
    // Password hashing moved to SQLite service
    throw UnimplementedError('Firebase removed - use SQLiteService for password hashing');
  }

  Future<dynamic> signInWithUsername({required String username, required String password}) async {
    throw UnimplementedError('Firebase removed - use UnifiedDataService.authenticateUser() instead');
  }

  Future<dynamic> signInWithEmail({required String email, required String password}) async {
    throw UnimplementedError('Firebase removed - use UnifiedDataService.authenticateUser() instead');
  }

  Future<void> sendPasswordResetEmail(String email) async {
    throw UnimplementedError('Firebase removed - use TwoFactorAuthService for password reset');
  }

  Future<void> changePassword(String email, String newPassword) async {
    throw UnimplementedError('Firebase removed - use UnifiedDataService.updatePassword() instead');
  }

  Future<void> updatePasswordAfterEmailReset({required String email, required String newPassword}) async {
    throw UnimplementedError('Firebase removed - use TwoFactorAuthService.updatePasswordAfterReset() instead');
  }

  Future<void> signOut() async {
    // No-op for offline-only app
  }

  // Stub for database reference (not used in offline mode)
  dynamic get database => throw UnimplementedError('Firebase database removed - app is offline-only');

  // Stub for message streams (not used in offline mode)
  Stream<dynamic> getMessagesStream(String chatId) {
    throw UnimplementedError('Firebase messaging removed - app is offline-only');
  }

  // Initialize method (no-op for offline-only app)
  static Future<void> initialize() async {
    // Firebase initialization removed - app is offline-only
  }
}
