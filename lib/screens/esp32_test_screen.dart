import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/simple_bluetooth_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// ESP32 Testing and Debug Screen
class ESP32TestScreen extends StatefulWidget {
  const ESP32TestScreen({super.key});

  @override
  State<ESP32TestScreen> createState() => _ESP32TestScreenState();
}

class _ESP32TestScreenState extends State<ESP32TestScreen> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _addLog('ESP32 Test Screen initialized');
    
    // Listen to status updates
    final btService = Provider.of<SimpleBluetoothService>(context, listen: false);
    btService.statusStream.listen((status) {
      _addLog('[STATUS] $status');
    });
    
    btService.messageStream.listen((message) {
      _addLog('[MESSAGE] ${message.toString()}');
    });
  }

  void _addLog(String log) {
    if (mounted) {
      setState(() {
        _logs.add('[${DateTime.now().toString().substring(11, 19)}] $log');
        if (_logs.length > 100) _logs.removeAt(0);
      });
      
      // Auto-scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ESP32 Debug Console'),
        backgroundColor: AppColors.primaryRed,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() => _logs.clear());
              _addLog('Logs cleared');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionControls(),
          _buildTestControls(),
          Expanded(child: _buildLogConsole()),
        ],
      ),
    );
  }

  Widget _buildConnectionControls() {
    return Consumer<SimpleBluetoothService>(
      builder: (context, btService, child) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connection Status',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    btService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: btService.isConnected ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      btService.connectionStatus,
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (btService.isAuthenticated) ...[
                const SizedBox(height: 8),
                Text('Node ID: ${btService.esp32NodeId}', style: AppTypography.bodySmall),
                Text('User: ${btService.userName}', style: AppTypography.bodySmall),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: btService.isConnected
                          ? null
                          : () async {
                              _addLog('Initiating connection...');
                              final success = await btService.connectToESP32();
                              _addLog(success ? 'Connection initiated' : 'Connection failed');
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bluetooth_disabled),
                      label: const Text('Disconnect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mediumGray,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: !btService.isConnected
                          ? null
                          : () async {
                              _addLog('Disconnecting...');
                              await btService.disconnect();
                              _addLog('Disconnected');
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTestControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test Messages',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTestButton('Test Group', () => _sendTestMessage('group')),
              _buildTestButton('Test Private', () => _sendTestMessage('private')),
              _buildTestButton('Ping', () => _sendPing()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(String label, VoidCallback onPressed) {
    return Consumer<SimpleBluetoothService>(
      builder: (context, btService, child) {
        return ElevatedButton(
          onPressed: btService.isAuthenticated ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.online,
            foregroundColor: Colors.white,
          ),
          child: Text(label),
        );
      },
    );
  }

  Widget _buildLogConsole() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text(
                'Debug Console',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_logs.length} logs',
                style: AppTypography.bodySmall.copyWith(color: AppColors.lightGray),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Text(
                      'No logs yet...',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.mediumGray),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      Color textColor = AppColors.lightGray;
                      
                      if (log.contains('[ERROR]')) textColor = AppColors.error;
                      else if (log.contains('[STATUS]')) textColor = AppColors.online;
                      else if (log.contains('[MESSAGE]')) textColor = AppColors.success;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: SelectableText(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: textColor,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _sendTestMessage(String type) async {
    final btService = Provider.of<SimpleBluetoothService>(context, listen: false);
    
    final testMessage = 'Test message at ${DateTime.now().toString().substring(11, 19)}';
    
    _addLog('[SEND] Type: $type, Message: $testMessage');
    
    if (type == 'group') {
      await btService.sendGroupMessage(testMessage);
    } else {
      await btService.sendPrivateMessage(testMessage, 'TEST_NODE');
    }
    
    _addLog('[SENT] Message queued for transmission');
  }

  void _sendPing() async {
    final btService = Provider.of<SimpleBluetoothService>(context, listen: false);
    
    final testMessage = 'PING at ${DateTime.now().toString().substring(11, 19)}';
    
    _addLog('[PING] Sending ping...');
    await btService.sendGroupMessage(testMessage);
    _addLog('[PING] Sent');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

