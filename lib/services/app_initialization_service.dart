import 'package:flutter/foundation.dart';
import 'unified_data_service.dart';
import 'disaster_classification_service.dart';

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
      
      // Optional: Preload AI disaster classification model in background
      // so it is ready when user opens Emergency Detection screen
      _preloadMLModelInBackground();
    } catch (e) {
      debugPrint('❌ Failed to initialize app services: $e');
      rethrow;
    }
  }
  
  /// Preload ML model in background (non-blocking). Does not fail app startup.
  void _preloadMLModelInBackground() {
    Future<void>.delayed(const Duration(seconds: 2), () async {
      try {
        final service = DisasterClassificationService.instance;
        if (service.isModelLoaded) return;
        debugPrint('🔄 Background: Preloading AI disaster classification model...');
        final ok = await service.loadModel().timeout(
          const Duration(seconds: 90),
          onTimeout: () {
            debugPrint('⚠️ Background ML preload timed out');
            return false;
          },
        );
        if (ok) debugPrint('✅ Background: AI model ready');
      } catch (e) {
        debugPrint('⚠️ Background ML preload failed: $e');
      }
    });
  }
  
  /// Check if services are initialized
  bool get isInitialized => _isInitialized;
}
