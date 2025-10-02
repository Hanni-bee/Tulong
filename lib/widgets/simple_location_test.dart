import 'package:flutter/material.dart';
import '../services/location_service.dart';

class SimpleLocationTest extends StatefulWidget {
  const SimpleLocationTest({super.key});

  @override
  State<SimpleLocationTest> createState() => _SimpleLocationTestState();
}

class _SimpleLocationTestState extends State<SimpleLocationTest> {
  String _status = 'Testing...';
  List<Map<String, dynamic>> _regions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _testLocationService();
  }

  Future<void> _testLocationService() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading regions...';
    });

    try {
      final regions = await LocationService.getRegions();
      setState(() {
        _regions = regions;
        _isLoading = false;
        _status = '✅ Success! Loaded ${regions.length} regions';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = '❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _status.contains('✅') ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _status.contains('✅') ? Colors.green : Colors.red,
                ),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  color: _status.contains('✅') ? Colors.green[800] : Colors.red[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _regions.length,
                  itemBuilder: (context, index) {
                    final region = _regions[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(region['name'] ?? 'Unknown'),
                        subtitle: Text('Code: ${region['code']}'),
                      ),
                    );
                  },
                ),
              ),
            ElevatedButton(
              onPressed: _testLocationService,
              child: const Text('Test Again'),
            ),
          ],
        ),
      ),
    );
  }
}
