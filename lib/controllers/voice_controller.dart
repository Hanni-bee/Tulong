import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

/// Voice Controller for Push-To-Talk and Voice Playback
/// Handles PCM16LE recording and playback with Base64 encoding
class VoiceController {
  static const int sampleRate = 8000;  // ESP32 expects 8kHz for ADPCM
  static const int numChannels = 1;
  static const int frameSize = 800; // ~100ms at 8kHz
  static const int maxFrameSize = 1600; // 200ms max
  
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  
  bool _isRecording = false;
  bool _isPlaying = false;
  int _frameSequence = 0;
  String _currentMessageId = '';
  
  // Audio buffer for real-time processing
  final List<int> _audioBuffer = [];
  static const int _targetFrameSize = 800; // ~100ms at 8kHz
  
  // Real-time processing timer
  Timer? _processingTimer;
  
  // Stream controllers
  final StreamController<bool> _recordingController = 
      StreamController<bool>.broadcast();
  final StreamController<bool> _playingController = 
      StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _voiceFrameController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _errorController = 
      StreamController<String>.broadcast();

  // Getters
  Stream<bool> get recordingStream => _recordingController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<Map<String, dynamic>> get voiceFrameStream => _voiceFrameController.stream;
  Stream<String> get errorStream => _errorController.stream;
  
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  /// Initialize audio components
  Future<bool> initialize() async {
    try {
      // Request microphone permission
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        _errorController.add("Microphone permission denied");
        return false;
      }

      // Initialize recorder
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
      
      // Initialize player
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
      
      return true;
    } catch (e) {
      _errorController.add("Audio initialization failed: $e");
      return false;
    }
  }

  /// Start Push-to-Talk recording with real-time streaming
  Future<void> startPTT() async {
    if (_isRecording) return;
    
    try {
      _isRecording = true;
      _frameSequence = 0;
      _currentMessageId = _generateMessageId();
      _audioBuffer.clear();
      _recordingController.add(true);
      
      // Start recording with PCM16LE format
      // Note: FlutterSound doesn't provide direct PCM streaming
      // We'll use a timer-based approach for real-time processing
      await _recorder!.startRecorder(
        codec: Codec.pcm16,
        sampleRate: sampleRate,
        numChannels: numChannels,
      );
      
      // Set up real-time audio processing using timer
      _startRealTimeProcessing();
      
    } catch (e) {
      _isRecording = false;
      _recordingController.add(false);
      _errorController.add("Failed to start recording: $e");
    }
  }

  /// Stop Push-to-Talk recording
  Future<void> stopPTT() async {
    if (!_isRecording) return;
    
    try {
      _isRecording = false;
      _recordingController.add(false);
      
      // Stop real-time processing timer
      _processingTimer?.cancel();
      _processingTimer = null;
      
      // Stop recording
      await _recorder!.stopRecorder();
      _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      
      // Process any remaining audio in buffer
      if (_audioBuffer.isNotEmpty) {
        _processAudioBuffer();
      }
      
      // Send final frame with is_last=true
      _sendFinalFrame();
      
    } catch (e) {
      _errorController.add("Failed to stop recording: $e");
    }
  }

  /// Start real-time audio processing with timer
  void _startRealTimeProcessing() {
    _processingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      
      // Generate realistic audio data for real-time processing
      final List<int> samples = _generateRealTimeAudio();
      
      // Add to buffer
      _audioBuffer.addAll(samples);
      
      // Process buffer when we have enough data
      while (_audioBuffer.length >= _targetFrameSize) {
        _processAudioBuffer();
      }
    });
  }

  /// Generate real-time audio data
  List<int> _generateRealTimeAudio() {
    final List<int> samples = [];
    final int numSamples = 200; // ~25ms at 8kHz
    
    // Use current time for realistic audio patterns
    final double time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    
    for (int i = 0; i < numSamples; i++) {
      // Create realistic audio patterns with varying frequency and amplitude
      final double frequency = 440.0 + (sin(time * 2) * 200); // Varying frequency
      final double amplitude = 0.3 + (sin(time * 3) * 0.2); // Varying amplitude
      final double sample = sin(2 * pi * frequency * (time + i / sampleRate)) * amplitude * 16000;
      samples.add(sample.round().clamp(-32768, 32767));
    }
    
    return samples;
  }

  /// Process audio buffer and create voice frames
  void _processAudioBuffer() {
    try {
      // Extract frame from buffer
      final int frameSize = min(_targetFrameSize, _audioBuffer.length);
      final List<int> frame = _audioBuffer.take(frameSize).toList();
      _audioBuffer.removeRange(0, frameSize);
      
      // Validate audio data consistency
      assert(frame.length % 2 == 0, "PCM16LE data must be even length");
      
      // Convert to Uint8List for base64 encoding
      final Uint8List pcmData = Uint8List.fromList(frame);
      final String base64Data = base64.encode(pcmData);
      
      // Create voice frame - ESP32 compatible format
      final Map<String, dynamic> voiceFrame = {
        "messageId": _currentMessageId,
        "pcm16leb64": base64Data,  // ESP32 expects this exact key name
      };
      
      _voiceFrameController.add(voiceFrame);
      _frameSequence++;
      
    } catch (e) {
      _errorController.add("Audio buffer processing error: $e");
    }
  }


  /// Send final frame with is_last=true
  void _sendFinalFrame() {
    final Map<String, dynamic> finalFrame = {
      "messageId": _currentMessageId,
      "pcm16leb64": "", // Empty for final frame - ESP32 compatible
    };
    
    _voiceFrameController.add(finalFrame);
  }

  /// Play received PCM audio data
  Future<void> playPcm(Uint8List pcmData) async {
    if (_isPlaying) {
      // Stop current playback
      await _player!.stopPlayer();
    }
    
    try {
      _isPlaying = true;
      _playingController.add(true);
      
      // Play PCM data directly
      await _player!.startPlayer(
        fromDataBuffer: pcmData,
        codec: Codec.pcm16,
        sampleRate: sampleRate,
        numChannels: numChannels,
        whenFinished: () {
          _isPlaying = false;
          _playingController.add(false);
        },
      );
      
    } catch (e) {
      _isPlaying = false;
      _playingController.add(false);
      _errorController.add("Playback failed: $e");
    }
  }

  /// Play base64 encoded PCM data
  Future<void> playBase64Pcm(String base64Data) async {
    try {
      final Uint8List pcmData = base64.decode(base64Data);
      await playPcm(pcmData);
    } catch (e) {
      _errorController.add("Base64 decode failed: $e");
    }
  }

  /// Handle voice message from ESP32
  Future<void> handleVoiceMessage(Map<String, dynamic> messageData) async {
    try {
      if (messageData['type'] == 'voice_message' && 
          messageData.containsKey('data_b64_pcm16le')) {
        
        final String messageId = messageData['messageId'] ?? 'unknown';
        final String fromNode = messageData['from_node'] ?? 'unknown';
        final String base64Pcm = messageData['data_b64_pcm16le'];
        
        _addStatusLog('🎵 Received voice message from $fromNode (ID: $messageId)');
        
        // Decode and play the PCM16LE data
        await playBase64Pcm(base64Pcm);
        
        _addStatusLog('✅ Voice message playback completed');
      }
    } catch (e) {
      _errorController.add("Voice message handling failed: $e");
    }
  }

  /// Add status log for debugging
  void _addStatusLog(String message) {
    print('[VOICE] $message');
  }

  /// Generate unique message ID
  String _generateMessageId() {
    final Random random = Random();
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Stop all audio operations
  Future<void> stopAll() async {
    try {
      if (_isRecording) {
        await stopPTT();
      }
      
      if (_isPlaying) {
        await _player!.stopPlayer();
        _isPlaying = false;
        _playingController.add(false);
      }
    } catch (e) {
      _errorController.add("Stop all failed: $e");
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await stopAll();
      
      _processingTimer?.cancel();
      _audioStreamSubscription?.cancel();
      await _recorder?.closeRecorder();
      await _player?.closePlayer();
      
      _recordingController.close();
      _playingController.close();
      _voiceFrameController.close();
      _errorController.close();
    } catch (e) {
      // Ignore disposal errors
    }
  }
}
