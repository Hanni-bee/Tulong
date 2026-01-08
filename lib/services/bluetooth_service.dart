import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  BluetoothConnection? _connection;
  final StreamController<String> _messageController = StreamController<String>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<String> _debugController = StreamController<String>.broadcast();
  
  // Line buffer for accumulating data across Bluetooth packets
  String _lineBuffer = '';
  
  Stream<String> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String> get debugStream => _debugController.stream;
  
  bool get isConnected => _connection?.isConnected ?? false;
  final Uuid _uuid = const Uuid();

  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      _debugController.add('Found ${devices.length} paired devices');
      return devices;
    } catch (e) {
      _debugController.add('Error getting paired devices: $e');
      return [];
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _debugController.add('Attempting to connect to ${device.name}...');
      
      _connection = await BluetoothConnection.toAddress(device.address);
      
      if (_connection?.isConnected == true) {
        _debugController.add('Connected to ${device.name}');
        _connectionController.add(true);
        
        _connection!.input!.listen(
          (Uint8List data) {
            String chunk = utf8.decode(data);
            _lineBuffer += chunk;
            _debugController.add('Received chunk: ${chunk.length} chars, buffer: ${_lineBuffer.length} chars');
            
            // Process complete lines
            while (_lineBuffer.contains('\n')) {
              int newlineIndex = _lineBuffer.indexOf('\n');
              String completeLine = _lineBuffer.substring(0, newlineIndex);
              _lineBuffer = _lineBuffer.substring(newlineIndex + 1);
              
              if (completeLine.isNotEmpty) {
                _debugController.add('Received line: ${completeLine.length} chars');
                _messageController.add('$completeLine\n');
              }
            }
          },
          onDone: () {
            _debugController.add('Bluetooth connection lost (onDone)');
            _connectionController.add(false);
            _connection = null;
          },
          onError: (error) {
            _debugController.add('Bluetooth error: $error');
            _connectionController.add(false);
            _connection = null;
          },
        );

        // Send receiver ID once per install to Node B immediately after connect
        unawaited(_sendReceiverId());
        return true;
      } else {
        _debugController.add('Failed to connect to ${device.name}');
        return false;
      }
    } catch (e) {
      _debugController.add('Connection error: $e');
      return false;
    }
  }

  Future<bool> sendMessage(String message) async {
    if (_connection?.isConnected != true) {
      _debugController.add('Cannot send message: not connected');
      return false;
    }
    try {
      // Ensure message ends with newline for ESP32 compatibility
      String messageWithNewline = message.endsWith('\n') ? message : '$message\n';
      
      _connection!.output.add(utf8.encode(messageWithNewline));
      await _connection!.output.allSent;
      
      _debugController.add('Sent: $message');
      return true;
    } catch (e) {
      _debugController.add('Error sending message: $e');
      return false;
    }
  }

  /// Generate (if needed) and send receiver_id to Node B/ESP32.
  Future<void> _sendReceiverId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var receiverId = prefs.getString('receiver_id');
      if (receiverId == null || receiverId.isEmpty) {
        receiverId = _uuid.v4();
        await prefs.setString('receiver_id', receiverId);
      }

      final payload = StringBuffer()
        ..writeln('<RECEIVER_ID>')
        ..writeln('ID=$receiverId')
        ..write('<END_RECEIVER_ID>');

      await sendMessage(payload.toString());
      _debugController.add('Sent receiver_id: $receiverId');
    } catch (e) {
      _debugController.add('Error sending receiver_id: $e');
    }
  }

  /// Send profile header update to Node A (FULLNAME + ADDRESS)
  Future<bool> sendProfileHeader({
    required String fullName,
    required String address,
  }) async {
    final payload = StringBuffer()
      ..writeln('<SET_PROFILE>')
      ..writeln('FULLNAME=$fullName')
      ..writeln('ADDRESS=$address')
      ..write('<END_PROFILE>');
    return sendMessage(payload.toString());
  }

  /// Send SOS message to Node A (<=200 chars)
  Future<bool> sendSosMessage(String message) async {
    final trimmed = message.trim();
    final int maxLen = trimmed.length > 200 ? 200 : trimmed.length;
    final payload = StringBuffer()
      ..writeln('<SOS>')
      ..writeln('MESSAGE=${trimmed.substring(0, maxLen)}')
      ..write('<END_SOS>');
    return sendMessage(payload.toString());
  }

  Future<void> disconnect() async {
    try {
      await _connection?.close();
      _connection = null;
      _lineBuffer = '';  // Clear buffer on disconnect
      _connectionController.add(false);
      _debugController.add('Disconnected from device');
    } catch (e) {
      _debugController.add('Error disconnecting: $e');
    }
  }
  
  void dispose() {
    _messageController.close();
    _connectionController.close();
    _debugController.close();
  }
}

