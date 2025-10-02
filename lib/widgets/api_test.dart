import 'package:flutter/material.dart';
import '../services/location_service.dart';

class ApiTest extends StatefulWidget {
  const ApiTest({super.key});

  @override
  State<ApiTest> createState() => _ApiTestState();
}

class _ApiTestState extends State<ApiTest> {
  String _status = 'Testing API...';
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _testApi();
  }

  Future<void> _testApi() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing Philippine Location API...';
    });

    try {
      // Test the complete data structure
      final data = await LocationService.getCompleteData();
      
      if (data != null) {
        setState(() {
          _data = data;
          _isLoading = false;
          _status = 'API Test Successful!';
        });
        
        print('API Test Results:');
        print('Available sections: ${data.keys.toList()}');
        
        if (data.containsKey('regions')) {
          final regions = data['regions'] as List;
          print('Regions: ${regions.length}');
          if (regions.isNotEmpty) {
            print('Sample region: ${regions.first}');
          }
        }
        
        if (data.containsKey('provinces')) {
          final provinces = data['provinces'] as List;
          print('Provinces: ${provinces.length}');
          if (provinces.isNotEmpty) {
            print('Sample province: ${provinces.first}');
          }
        }
        
        if (data.containsKey('cities')) {
          final cities = data['cities'] as List;
          print('Cities: ${cities.length}');
          if (cities.isNotEmpty) {
            print('Sample city: ${cities.first}');
          }
        }
        
        if (data.containsKey('municipalities')) {
          final municipalities = data['municipalities'] as List;
          print('Municipalities: ${municipalities.length}');
          if (municipalities.isNotEmpty) {
            print('Sample municipality: ${municipalities.first}');
          }
        }
        
        if (data.containsKey('barangays')) {
          final barangays = data['barangays'] as List;
          print('Barangays: ${barangays.length}');
          if (barangays.isNotEmpty) {
            print('Sample barangay: ${barangays.first}');
          }
        }
      } else {
        setState(() {
          _isLoading = false;
          _status = 'API Test Failed - No data received';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'API Test Failed: $e';
      });
      print('API Test Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Philippine Location API Test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _status.contains('Successful') ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _status.contains('Successful') ? Colors.green : Colors.red,
                  ),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    color: _status.contains('Successful') ? Colors.green[800] : Colors.red[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              if (_data != null) ...[
                const SizedBox(height: 20),
                const Text(
                  'Data Structure:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...(_data!.keys.map((key) {
                  final count = _data![key] is List ? (_data![key] as List).length : 'N/A';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text('$key: '),
                        Text(
                          count.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList()),
              ],
              
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _testApi,
                child: const Text('Test Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
