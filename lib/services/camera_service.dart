import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for managing camera operations
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  
  /// Get camera controller
  CameraController? get controller => _controller;
  
  /// Check if camera is initialized
  bool get isInitialized => _isInitialized;
  
  /// Get available cameras
  Future<List<CameraDescription>> getAvailableCameras() async {
    try {
      _cameras ??= await availableCameras();
      return _cameras!;
    } catch (e) {
      debugPrint('Error getting cameras: $e');
      return [];
    }
  }
  
  /// Initialize camera (use back camera by default)
  Future<bool> initializeCamera({bool useFrontCamera = false}) async {
    try {
      // Dispose existing controller if any
      await dispose();
      
      // Get available cameras
      final cameras = await getAvailableCameras();
      if (cameras.isEmpty) {
        debugPrint('No cameras available');
        return false;
      }
      
      // Select camera (back camera preferred for emergency detection)
      CameraDescription selectedCamera;
      if (useFrontCamera) {
        selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
      } else {
        selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
      }
      
      // Create controller with high resolution for better AI processing
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high, // High resolution for better AI accuracy
        enableAudio: false, // No audio needed for emergency detection
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      // Initialize controller
      await _controller!.initialize();
      
      _isInitialized = true;
      debugPrint('Camera initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      _isInitialized = false;
      return false;
    }
  }
  
  /// Take a picture
  Future<String?> takePicture() async {
    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized) {
      debugPrint('Camera not initialized');
      return null;
    }
    
    try {
      // Take picture
      final XFile image = await _controller!.takePicture();
      
      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'emergency_$timestamp.jpg';
      final String filePath = path.join(tempDir.path, fileName);
      
      // Copy to temporary directory (for easier access)
      final File savedImage = await File(image.path).copy(filePath);
      
      debugPrint('Picture saved to: ${savedImage.path}');
      return savedImage.path;
    } catch (e) {
      debugPrint('Error taking picture: $e');
      return null;
    }
  }
  
  /// Dispose camera controller
  Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      _isInitialized = false;
      debugPrint('Camera disposed');
    }
  }
  
  /// Check if camera is ready
  bool get isReady => _isInitialized && _controller != null && _controller!.value.isInitialized;
}


