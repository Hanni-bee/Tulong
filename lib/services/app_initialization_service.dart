import 'package:flutter/foundation.dart';
import 'unified_data_service.dart';

/// Service to initialize all app services on startup
class AppInitializationService {
  static final AppInitializationService _instance = AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  bool _isInitialized = false;
  
  /// Initialize all services
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🚀 Initializing app services...');
      
      // Initialize unified data service
      await UnifiedDataService().initialize();
      
      _isInitialized = true;
      debugPrint('✅ App services initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize app services: $e');
      rethrow;
    }
  }
  
  /// Check if services are initialized
  bool get isInitialized => _isInitialized;
}
