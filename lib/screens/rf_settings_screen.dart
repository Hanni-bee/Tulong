import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';

class RfSettingsScreen extends StatefulWidget {
  const RfSettingsScreen({super.key});

  @override
  State<RfSettingsScreen> createState() => _RfSettingsScreenState();
}

class _RfSettingsScreenState extends State<RfSettingsScreen> {
  late final TextEditingController _channelController;

  @override
  void initState() {
    super.initState();
    final current = context.read<ChatProvider>().rfChannel;
    _channelController = TextEditingController(text: current.toString());
  }

  @override
  void dispose() {
    _channelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RF Channel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Set ESP32 nRF24 channel (0-125).'),
            const SizedBox(height: 12),
            TextField(
              controller: _channelController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'RF channel',
                helperText: 'Default firmware value is 108',
              ),
            ),
            const SizedBox(height: 16),
            Consumer<ChatProvider>(
              builder: (context, chat, _) {
                return ElevatedButton(
                  onPressed: () async {
                    final v = int.tryParse(_channelController.text.trim());
                    if (v == null || v < 0 || v > 125) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Use a value from 0 to 125')),
                      );
                      return;
                    }
                    final ok = await chat.setRfChannel(v);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'RF channel updated to $v' : 'Failed to update RF channel')),
                    );
                  },
                  child: const Text('Save channel'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
