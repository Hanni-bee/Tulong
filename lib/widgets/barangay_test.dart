import 'package:flutter/material.dart';
import '../services/location_service.dart';

class BarangayTest extends StatefulWidget {
  const BarangayTest({super.key});

  @override
  State<BarangayTest> createState() => _BarangayTestState();
}

class _BarangayTestState extends State<BarangayTest> {
  String _status = 'Testing barangay loading...';
  List<Map<String, dynamic>> _barangays = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testBarangayLoading();
  }

  Future<void> _testBarangayLoading() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading barangays from CALOOCAN CITY...';
    });

    try {
      final barangays = await LocationService.getBarangays('CALOOCAN CITY');
      setState(() {
        _barangays = barangays;
        _isLoading = false;
        _status = '✅ Loaded ${barangays.length} barangays from CALOOCAN CITY';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = '❌ Error loading barangays: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barangay Test'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                'Barangays in CALOOCAN CITY: ${_barangays.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              
              // Barangays List
              Expanded(
                child: ListView.builder(
                  itemCount: _barangays.length,
                  itemBuilder: (context, index) {
                    final barangay = _barangays[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.home, color: Colors.teal),
                        title: Text(barangay['name'] ?? 'Unknown'),
                        subtitle: Text('City: ${barangay['city']}'),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Test Again Button
              ElevatedButton(
                onPressed: _testBarangayLoading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
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
