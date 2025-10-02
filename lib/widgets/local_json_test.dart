import 'package:flutter/material.dart';
import '../services/location_service.dart';

class LocalJsonTest extends StatefulWidget {
  const LocalJsonTest({super.key});

  @override
  State<LocalJsonTest> createState() => _LocalJsonTestState();
}

class _LocalJsonTestState extends State<LocalJsonTest> {
  String _status = 'Testing local JSON file...';
  List<Map<String, dynamic>> _regions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _testLocalJson();
  }

  Future<void> _testLocalJson() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading regions from local JSON...';
    });

    try {
      final regions = await LocationService.getRegions();
      setState(() {
        _regions = regions;
        _isLoading = false;
        _status = '✅ Local JSON loaded successfully!';
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
        title: const Text('Local JSON Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Philippine Location Data Test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Status
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
              const Center(child: CircularProgressIndicator())
            else ...[
              Text(
                'Regions Loaded: ${_regions.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              
              // Regions List
              Expanded(
                child: ListView.builder(
                  itemCount: _regions.length,
                  itemBuilder: (context, index) {
                    final region = _regions[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.blue),
                        title: Text(
                          region['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Code: ${region['code']}'),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Test Again Button
              ElevatedButton(
                onPressed: _testLocalJson,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Test Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
