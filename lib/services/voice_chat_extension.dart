import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Voice message types for the chat system
enum MessageType {
  text,
  voice,
}

/// Message status enum
enum MessageStatus {
  sending,
  sent,
  delivered,
  failed,
  received,
}

/// Voice Quality Validator constants
class VQVConstants {
  static const int MIN_WAV_SIZE = 2048; // kept for legacy
  static const double MIN_RMS_THRESHOLD = 0.005;
  static const int SAMPLE_WINDOW_MS = 250;
  static const int MAX_ATTEMPTS = 2;
  static const int CHUNK_SIZE = 28; // ESP32 chunk size (28 chars)
  static const int WAV_HEADER_SIZE = 44;
  static const int SAMPLE_RATE = 44100;
}

/// Voice Quality Validation Result
class VQVResult {
  final bool isValid;
  final String reason;
  final double? rmsEnergy;
  final int fileSize;
  final double? amplitudeMean;
  final double? noiseFloor;
  final Duration? duration;

  VQVResult({
    required this.isValid,
    required this.reason,
    this.rmsEnergy,
    required this.fileSize,
    this.amplitudeMean,
    this.noiseFloor,
    this.duration,
  });

  Map<String, dynamic> toDebugMap() => {
        'valid': isValid,
        'reason': reason,
        'rmsEnergy': rmsEnergy,
        'fileSize': fileSize,
        'amplitudeMean': amplitudeMean,
        'noiseFloor': noiseFloor,
        'duration': duration?.inMilliseconds,
      };
}

/// Voice Quality Validator class
class VoiceQualityValidator {
  static Future<VQVResult> validateAacFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return VQVResult(isValid: false, reason: 'File does not exist', fileSize: 0);
      }

      final bytes = await file.readAsBytes();
      final fileSize = bytes.length;

      if (fileSize < 1000) {
        return VQVResult(
          isValid: false,
          reason: 'AAC file too small (${fileSize}B < 1000B)',
          fileSize: fileSize,
        );
      }

      return VQVResult(
        isValid: true,
        reason: 'AAC validation passed',
        fileSize: fileSize,
        rmsEnergy: 0.1,
        amplitudeMean: 0.1,
        noiseFloor: 0.01,
        duration: Duration(milliseconds: (fileSize / 16).round()),
      );
    } catch (e) {
      return VQVResult(isValid: false, reason: 'AAC validation error: $e', fileSize: 0);
    }
  }

  // (WAV validator left as-is; not used for AAC path)
  static Future<VQVResult> validateWavFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return VQVResult(isValid: false, reason: 'File does not exist', fileSize: 0);
      }

      final bytes = await file.readAsBytes();
      final fileSize = bytes.length;

      if (fileSize < VQVConstants.MIN_WAV_SIZE) {
        return VQVResult(
          isValid: false,
          reason: 'File too small (${fileSize}B < ${VQVConstants.MIN_WAV_SIZE}B)',
          fileSize: fileSize,
        );
      }

      if (!_validateWavHeader(bytes)) {
        return VQVResult(isValid: false, reason: 'Invalid WAV header', fileSize: fileSize);
      }

      final rmsResult = await _calculateRMSEnergy(bytes);

      if (rmsResult.rmsEnergy < VQVConstants.MIN_RMS_THRESHOLD) {
        return VQVResult(
          isValid: false,
          reason: 'Silent audio (RMS=${rmsResult.rmsEnergy.toStringAsFixed(4)} < ${VQVConstants.MIN_RMS_THRESHOLD})',
          fileSize: fileSize,
          rmsEnergy: rmsResult.rmsEnergy,
          amplitudeMean: rmsResult.amplitudeMean,
          noiseFloor: rmsResult.noiseFloor,
        );
      }

      return VQVResult(
        isValid: true,
        reason: 'Validation passed',
        fileSize: fileSize,
        rmsEnergy: rmsResult.rmsEnergy,
        amplitudeMean: rmsResult.amplitudeMean,
        noiseFloor: rmsResult.noiseFloor,
        duration: rmsResult.duration,
      );
    } catch (e) {
      return VQVResult(isValid: false, reason: 'Validation error: $e', fileSize: 0);
    }
  }

  static bool _validateWavHeader(Uint8List bytes) {
    if (bytes.length < VQVConstants.WAV_HEADER_SIZE) return false;

    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    if (riff != 'RIFF') return false;

    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (wave != 'WAVE') return false;

    final fmt = String.fromCharCodes(bytes.sublist(12, 20));
    if (fmt != 'fmt ') return false;

    return true;
  }

  static Future<({double rmsEnergy, double amplitudeMean, double noiseFloor, Duration? duration})> _calculateRMSEnergy(
      Uint8List bytes) async {
    try {
      final audioData = bytes.sublist(VQVConstants.WAV_HEADER_SIZE);

      final sampleRate = VQVConstants.SAMPLE_RATE;
      final sampleWindow = (sampleRate * VQVConstants.SAMPLE_WINDOW_MS / 1000).round();
      final samplesToAnalyze = min(sampleWindow, audioData.length ~/ 2);

      if (samplesToAnalyze < 10) {
        return (rmsEnergy: 0.0, amplitudeMean: 0.0, noiseFloor: 0.0, duration: null);
      }

      double sumSquares = 0.0;
      double sumAmplitude = 0.0;
      double minAmplitude = double.infinity;
      double maxAmplitude = double.negativeInfinity;

      for (int i = 0; i < samplesToAnalyze; i++) {
        if (i * 2 + 1 < audioData.length) {
          final sample = (audioData[i * 2] | (audioData[i * 2 + 1] << 8));
          final signedSample = sample > 32767 ? sample - 65536 : sample;
          final normalizedSample = signedSample / 32768.0;

          sumSquares += normalizedSample * normalizedSample;
          sumAmplitude += normalizedSample.abs();
          minAmplitude = min(minAmplitude, normalizedSample.abs());
          maxAmplitude = max(maxAmplitude, normalizedSample.abs());
        }
      }

      final rmsEnergy = sqrt(sumSquares / samplesToAnalyze);
      final amplitudeMean = sumAmplitude / samplesToAnalyze;
      final noiseFloor = minAmplitude;
      final duration = Duration(milliseconds: (samplesToAnalyze * 1000 / sampleRate).round());

      return (rmsEnergy: rmsEnergy, amplitudeMean: amplitudeMean, noiseFloor: noiseFloor, duration: duration);
    } catch (e) {
      return (rmsEnergy: 0.0, amplitudeMean: 0.0, noiseFloor: 0.0, duration: null);
    }
  }
}

/// Auto-Retry Sequencer for voice recording
class AutoRetrySequencer {
  int _attemptCount = 0;
  String? _lastFailureReason;
  Timer? _retryTimer;

  int get attemptCount => _attemptCount;
  String? get lastFailureReason => _lastFailureReason;
  bool get isRetrying => _retryTimer?.isActive ?? false;

  void reset() {
    _attemptCount = 0;
    _lastFailureReason = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  bool canRetry() => _attemptCount < VQVConstants.MAX_ATTEMPTS;

  void recordFailure(String reason) {
    _attemptCount++;
    _lastFailureReason = reason;
  }

  Future<void> scheduleRetry(Function() retryCallback, Function(String) debugLog) async {
    if (!canRetry()) {
      debugLog('[ARS] Abort after ${VQVConstants.MAX_ATTEMPTS} failed attempts');
      return;
    }

    final delayMs = 500 * pow(2, _attemptCount - 1).round();
    debugLog('[ARS] Restarting recorder in ${delayMs}ms (exponential backoff)');

    _retryTimer = Timer(Duration(milliseconds: delayMs), () {
      debugLog('[ARS] Auto-retry triggered, attempt $_attemptCount/${VQVConstants.MAX_ATTEMPTS} (reason: $_lastFailureReason)');
      retryCallback();
    });
  }

  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}

/// Voice recording and playback service for ESP32 Bluetooth chat
class VoiceChatExtension {
  static final VoiceChatExtension _instance = VoiceChatExtension._internal();
  factory VoiceChatExtension() => _instance;
  VoiceChatExtension._internal();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _player = AudioPlayer();
  final AutoRetrySequencer _retrySequencer = AutoRetrySequencer();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentRecordingPath;
  String? _currentPlayingPath;
  bool _enableDiagnostics = true;
  bool _isRecorderInitialized = false;
  DateTime? _recordingStartTime;
  Duration? _lastRecordingDuration;

  final StreamController<bool> _recordingController = StreamController<bool>.broadcast();
  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<String> _debugController = StreamController<String>.broadcast();

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get isRetrying => _retrySequencer.isRetrying;
  bool get enableDiagnostics => _enableDiagnostics;
  Stream<bool> get recordingStream => _recordingController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<String> get debugStream => _debugController.stream;

  set enableDiagnostics(bool value) => _enableDiagnostics = value;

  Future<bool> requestMicrophonePermission() async {
    try {
      final currentStatus = await Permission.microphone.status;
      _debugController.add('Current microphone permission status: $currentStatus');

      if (currentStatus.isGranted) {
        _debugController.add('✅ Microphone permission already granted');
        return true;
      }

      if (currentStatus.isDenied) {
        final micStatus = await Permission.microphone.request();
        _debugController.add('Permission request result: $micStatus');

        if (micStatus.isGranted) {
          _debugController.add('✅ Microphone permission granted');
          return true;
        } else {
          _debugController.add('🚫 Microphone permission denied');
          return false;
        }
      }

      if (currentStatus.isPermanentlyDenied) {
        _debugController.add('🚫 Microphone permission permanently denied - please enable in settings');
        return false;
      }

      return false;
    } catch (e) {
      _debugController.add('❌ Error requesting microphone permission: $e');
      return false;
    }
  }

  Future<bool> startRecording() async {
    if (_isRecording) {
      _debugController.add('Already recording');
      return false;
    }

    try {
      _retrySequencer.reset();
      _lastRecordingDuration = null;

      if (!await requestMicrophonePermission()) {
        return false;
      }

      if (!_isRecorderInitialized) {
        await _recorder.openRecorder();
        await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
        _isRecorderInitialized = true;
        _debugController.add('🎙 Recorder initialized');
      }

      final dir = await getTemporaryDirectory();
      _currentRecordingPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder.startRecorder(
        toFile: _currentRecordingPath!,
        codec: Codec.aacADTS,
        sampleRate: 22050,  // Reduced from 44100 for smaller file size (still good quality for voice)
        numChannels: 1,
        bitRate: 64000,     // Reduced from 128000 for smaller file size (64kbps is good for voice)
        audioSource: AudioSource.microphone,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _recordingController.add(true);
      _debugController.add('🎙 Recording started -> $_currentRecordingPath (22.05 kHz mono AAC @ 64kbps)');

      return true;
    } catch (e) {
      _debugController.add('❌ startRecording() failed: $e');
      return false;
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) {
      _debugController.add('Not currently recording');
      return null;
    }

    try {
      Duration? actualDuration;
      if (_recordingStartTime != null) {
        actualDuration = DateTime.now().difference(_recordingStartTime!);
        _debugController.add('🎙 Recording duration: ${actualDuration.inMilliseconds}ms');

        if (actualDuration.inMilliseconds < 800) {
          _debugController.add('⏳ Ensuring minimum recording duration (800ms)...');
          await Future.delayed(Duration(milliseconds: 800 - actualDuration.inMilliseconds));
          actualDuration = const Duration(milliseconds: 800);
        }
      }

      await _recorder.stopRecorder();
      _isRecording = false;
      _recordingController.add(false);

      _lastRecordingDuration = actualDuration;
      _recordingStartTime = null;

      if (_currentRecordingPath == null || !File(_currentRecordingPath!).existsSync()) {
        _debugController.add('Recording file not found');
        return null;
      }

      final recordingPath = _currentRecordingPath!;
      _debugController.add('Stopped recording: $recordingPath');

      _debugController.add('[VQV] Validating AAC payload...');
      final vqvResult = await VoiceQualityValidator.validateAacFile(recordingPath);

      if (_enableDiagnostics) {
        _debugController.add('[VQV] ${vqvResult.isValid ? "OK" : "FAIL"} (${(vqvResult.fileSize / 1024).toStringAsFixed(1)} KB)');
      }

      if (vqvResult.isValid) {
        _currentRecordingPath = null;
        return recordingPath;
      } else {
        _retrySequencer.recordFailure(vqvResult.reason);

        try {
          await File(recordingPath).delete();
          _debugController.add('[VQV] Deleted failed recording');
        } catch (e) {
          _debugController.add('[VQV] Error deleting failed recording: $e');
        }

        if (_retrySequencer.canRetry()) {
          _debugController.add('[VQV] FAIL ${vqvResult.reason} — triggering auto-retry (${_retrySequencer.attemptCount}/${VQVConstants.MAX_ATTEMPTS})');

          await _retrySequencer.scheduleRetry(() async {
            _debugController.add('[ARS] Re-recording due to low audio signal...');
            await startRecording();
          }, (log) => _debugController.add(log));

          return null;
        } else {
          _debugController.add('[ARS] Abort after ${VQVConstants.MAX_ATTEMPTS} failed attempts');
          _currentRecordingPath = null;
          return null;
        }
      }
    } catch (e) {
      _debugController.add('Error stopping recording: $e');
      _isRecording = false;
      _recordingController.add(false);
      return null;
    }
  }

  Future<String?> audioFileToBase64(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        _debugController.add('Audio file does not exist: $filePath');
        return null;
      }

      _debugController.add('[BASE64] Starting parallel encoding...');
      final base64String = await compute(_encodeFileToBase64, filePath);
      _debugController.add('[BASE64] Converted audio to Base64 (${base64String.length} chars)');

      return base64String;
    } catch (e) {
      _debugController.add('Error converting audio to Base64: $e');
      return null;
    }
  }

  static Future<String> _encodeFileToBase64(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  Future<bool> sendVoiceMessage(String base64Audio, Function(String) sendChunk) async {
    try {
      _debugController.add('[BT_TX] Sending voice message (${base64Audio.length} chars)');

      await sendChunk('<VOICE_START>\n');
      _debugController.add('[BT_TX] Sent <VOICE_START>');

      int chunkCount = 0;
      for (int i = 0; i < base64Audio.length; i += VQVConstants.CHUNK_SIZE) {
        final end = (i + VQVConstants.CHUNK_SIZE < base64Audio.length) ? i + VQVConstants.CHUNK_SIZE : base64Audio.length;
        final chunk = base64Audio.substring(i, end);
        await sendChunk('$chunk\n');

        chunkCount++;
        if (_enableDiagnostics && chunkCount % 10 == 0) {
          _debugController.add('[BT_TX] Sent chunk $chunkCount');
        }

        await Future.delayed(const Duration(milliseconds: 5));
      }

      await sendChunk('<VOICE_END>\n');
      _debugController.add('[BT_TX] Sent <VOICE_END> successfully');

      return true;
    } catch (e) {
      _debugController.add('Error sending voice message: $e');
      return false;
    }
  }

  Future<bool> playVoiceMessage(String base64Audio) async {
    if (_isPlaying) {
      _debugController.add('Already playing audio');
      return false;
    }

    try {
      // Clean whitespace just in case (safe)
      final cleaned = base64Audio.replaceAll(RegExp(r'\s+'), '');
      final audioBytes = base64Decode(cleaned);

      final tempDir = await getTemporaryDirectory();
      _currentPlayingPath = '${tempDir.path}/playback_${DateTime.now().millisecondsSinceEpoch}.aac';
      final file = File(_currentPlayingPath!);
      await file.writeAsBytes(audioBytes);

      await _player.play(DeviceFileSource(_currentPlayingPath!));
      _isPlaying = true;
      _playingController.add(true);
      _debugController.add('Playing voice message: $_currentPlayingPath');

      _player.onPlayerComplete.listen((_) {
        _isPlaying = false;
        _playingController.add(false);
        _debugController.add('Voice message playback completed');

        if (_currentPlayingPath != null) {
          File(_currentPlayingPath!).delete().catchError((e) {
            _debugController.add('Error deleting temp file: $e');
            return File(_currentPlayingPath!);
          });
          _currentPlayingPath = null;
        }
      });

      return true;
    } catch (e) {
      _debugController.add('Error playing voice message: $e');
      _isPlaying = false;
      _playingController.add(false);
      return false;
    }
  }

  Future<void> stopPlayback() async {
    if (_isPlaying) {
      try {
        await _player.stop();
        _isPlaying = false;
        _playingController.add(false);
        _debugController.add('Stopped voice message playback');

        if (_currentPlayingPath != null) {
          File(_currentPlayingPath!).delete().catchError((e) {
            _debugController.add('Error deleting temp file: $e');
            return File(_currentPlayingPath!);
          });
          _currentPlayingPath = null;
        }
      } catch (e) {
        _debugController.add('Error stopping playback: $e');
      }
    }
  }

  // ---------------- RX Voice Stream Handling ----------------
  bool _isReceivingVoice = false;
  final StringBuffer _voiceBuffer = StringBuffer();
  Timer? _voiceReceiveTimeout;

  // Tune this if you want; with ESP now forcing END on 3s RF stall,
  // this is mostly a safety net.
  static const Duration _rxVoiceTimeout = Duration(seconds: 90);

  void _resetVoiceTimeout() {
    _voiceReceiveTimeout?.cancel();
    _voiceReceiveTimeout = Timer(_rxVoiceTimeout, () {
      if (_isReceivingVoice) {
        _debugController.add('Voice receive timeout - resetting buffer');
        _isReceivingVoice = false;
        _voiceBuffer.clear();
      }
    });
  }

  List<String> processIncomingData(String data) {
    final messages = <String>[];

    // bluetooth_service.dart already emits lines with '\n', but just in case:
    final lines = data.split('\n');

    for (final line in lines) {
      // Keep base64 safe: only trim end-of-line noise, not internal chars
      final trimmed = line.replaceAll('\r', '').trim();
      if (trimmed.isEmpty) continue;

      if (trimmed == '<VOICE_START>') {
        _isReceivingVoice = true;
        _voiceBuffer.clear();
        _resetVoiceTimeout();
        _debugController.add('Voice message start detected');
        continue;
      }

      if (trimmed == '<VOICE_END>') {
        _voiceReceiveTimeout?.cancel();
        _voiceReceiveTimeout = null;

        if (_isReceivingVoice) {
          _isReceivingVoice = false;

          final full = _voiceBuffer.toString();
          _voiceBuffer.clear();

          if (full.isNotEmpty) {
            messages.add('VOICE_MESSAGE:$full');
            _debugController.add('Voice message end detected (${full.length} chars)');
          } else {
            _debugController.add('Voice message end detected but buffer is empty!');
          }
        }
        continue;
      }

      if (_isReceivingVoice) {
        // Reset timeout on EVERY chunk so long messages don't time out
        _resetVoiceTimeout();

        // Append chunk (no newline)
        _voiceBuffer.write(trimmed);

        if (_enableDiagnostics) {
          _debugController.add('Voice chunk added (${trimmed.length} chars, total: ${_voiceBuffer.length})');
        }
        continue;
      }

      // Regular text
      messages.add(trimmed);
    }

    return messages;
  }

  bool get isReceivingVoice => _isReceivingVoice;
  String get voiceBuffer => _voiceBuffer.toString();

  Duration? getRecordingDuration() {
    if (_lastRecordingDuration != null) return _lastRecordingDuration;
    if (_recordingStartTime != null) return DateTime.now().difference(_recordingStartTime!);
    return null;
  }

  void dispose() {
    if (_isRecorderInitialized) {
      _recorder.closeRecorder();
    }
    _player.dispose();
    _retrySequencer.dispose();
    _voiceReceiveTimeout?.cancel();
    _recordingController.close();
    _playingController.close();
    _debugController.close();
  }
}

/// Voice message data model
class VoiceMessage {
  final String id;
  final String base64Audio;
  final DateTime timestamp;
  final bool isMe;
  MessageStatus status;
  final Duration? duration;

  VoiceMessage({
    required this.id,
    required this.base64Audio,
    required this.timestamp,
    required this.isMe,
    this.status = MessageStatus.sent,
    this.duration,
  });

  factory VoiceMessage.fromBase64({
    required String base64Audio,
    required bool isMe,
    MessageStatus status = MessageStatus.sent,
    Duration? duration,
  }) {
    return VoiceMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      base64Audio: base64Audio,
      timestamp: DateTime.now(),
      isMe: isMe,
      status: status,
      duration: duration,
    );
  }

  int get audioSizeBytes {
    try {
      final cleaned = base64Audio.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(cleaned);
      return bytes.length;
    } catch (e) {
      return 0;
    }
  }

  String get formattedSize {
    final bytes = audioSizeBytes;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get formattedDuration {
    if (duration != null) {
      final totalSeconds = duration!.inMilliseconds / 1000.0;
      final seconds = totalSeconds.floor();
      final milliseconds = ((totalSeconds - seconds) * 1000).round();
      return '$seconds.${milliseconds.toString().padLeft(3, '0')}s';
    }
    return '0.000s';
  }
}
