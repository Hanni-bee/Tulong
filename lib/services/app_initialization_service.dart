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

      // Load the ML model first (background, non-blocking). Emergency Detection integrates once ready.
      _preloadMLModelInBackground();
    } catch (e) {
      debugPrint('❌ Failed to initialize app services: $e');
      rethrow;
    }
  }
  
  /// Preload ML model right after init (load first). Non-blocking so app stays responsive.
  void _preloadMLModelInBackground() {
    Future<void>(() async {
      try {
        final service = DisasterClassificationService.instance;
        if (service.isModelLoaded) {
          debugPrint('✅ AI model already loaded');
          return;
        }
        debugPrint('🔄 Loading AI disaster model first (this may take 10–30s)...');
        final ok = await service.loadModel().timeout(
          const Duration(seconds: 90),
          onTimeout: () {
            debugPrint('⚠️ ML model load timed out');
            return false;
          },
        );
        if (ok) {
          debugPrint('✅ AI model loaded and ready for detection');
        } else {
          debugPrint('⚠️ AI model load failed; detection screen will retry or use fallback');
        }
      } catch (e) {
        debugPrint('⚠️ AI model preload error: $e');
      }
    });
  }
  
  /// Check if services are initialized
  bool get isInitialized => _isInitialized;
}
