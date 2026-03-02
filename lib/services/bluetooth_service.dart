import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal() {
    // Listen for adapter state changes
    FlutterBluetoothSerial.instance.onStateChanged().listen((BluetoothState state) {
      print('BT_DEBUG: Adapter state changed to $state');
      _debugController.add('Adapter state: $state');
      
      if (state == BluetoothState.STATE_OFF || state == BluetoothState.STATE_TURNING_OFF) {
        // Adapter turned off, ensure we disconnect
        if (isConnected) {
          print('BT_DEBUG: Adapter off, forcing disconnect');
          disconnect();
        }
      }
    });
  }

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
      print('BT_DEBUG: connectToDevice() called for ${device.name} ${device.address}');
      _debugController.add('Attempting to connect to ${device.name}...');
      
      print('BT_DEBUG: Calling BluetoothConnection.toAddress(${device.address})...');
      _connection = await BluetoothConnection.toAddress(device.address);
      print('BT_DEBUG: toAddress() returned. isConnected=${_connection?.isConnected}');
      
      if (_connection?.isConnected == true) {
        print('BT_DEBUG: Connected!');
        _debugController.add('Connected to ${device.name}');
        _connectionController.add(true);
        
        _connection!.input!.listen(
          (Uint8List data) {
            final chunk = utf8.decode(data, allowMalformed: true);
            _lineBuffer += chunk;
            print('BT_DEBUG: RX chunk "${chunk.replaceAll("\n", "\\n")}"');
            _debugController.add('Received chunk: ${chunk.length} chars, buffer: ${_lineBuffer.length} chars');
            
            // Process complete lines
            while (_lineBuffer.contains('\n')) {
              final newlineIndex = _lineBuffer.indexOf('\n');
              final completeLine = _lineBuffer.substring(0, newlineIndex);
              _lineBuffer = _lineBuffer.substring(newlineIndex + 1);
              
              if (completeLine.trim().isNotEmpty) {
                print('BT_DEBUG: RX line "$completeLine"');
                _debugController.add('Received line: ${completeLine.length} chars');
                _messageController.add('$completeLine\n');
              }
            }
          },
          onDone: () {
            print('BT_DEBUG: onDone() connection closed');
            _debugController.add('Bluetooth connection lost (onDone)');
            _connectionController.add(false);
            _connection = null;
          },
          onError: (error) {
            print('BT_DEBUG: onError() $error');
            _debugController.add('Bluetooth error: $error');
            _connectionController.add(false);
            _connection = null;
          },
        );
        return true;
      } else {
        print('BT_DEBUG: Failed to connect (isConnected false)');
        _debugController.add('Failed to connect to ${device.name}');
        return false;
      }
    } catch (e) {
      print('BT_DEBUG: Connection error $e');
      _debugController.add('Connection error: $e');
      return false;
    }
  }

  Future<bool> sendMessage(String message) async {
    if (_connection?.isConnected != true) {
      print('BT_DEBUG: Cannot send message: not connected');
      _debugController.add('Cannot send message: not connected');
      return false;
    }
    try {
      // Ensure message ends with newline for ESP32 compatibility
      String messageWithNewline = message.endsWith('\n') ? message : '$message\n';
      
      print('BT_DEBUG: Sending message: "$message" (${messageWithNewline.length} bytes)');
      _connection!.output.add(utf8.encode(messageWithNewline));
      await _connection!.output.allSent;
      print('BT_DEBUG: Message sent successfully');
      
      _debugController.add('Sent: $message');
      return true;
    } catch (e) {
      print('BT_DEBUG: Error sending message: $e');
      _debugController.add('Error sending message: $e');
      return false;
    }
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

