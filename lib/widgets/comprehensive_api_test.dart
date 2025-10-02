import 'package:flutter/material.dart';
import '../services/location_service.dart';

class ComprehensiveApiTest extends StatefulWidget {
  const ComprehensiveApiTest({super.key});

  @override
  State<ComprehensiveApiTest> createState() => _ComprehensiveApiTestState();
}

class _ComprehensiveApiTestState extends State<ComprehensiveApiTest> {
  String _status = 'Testing all Philippine location APIs...';
  Map<String, dynamic> _results = {};
  bool _isLoading = true;
  List<String> _workingApis = [];
  List<String> _failedApis = [];

  @override
  void initState() {
    super.initState();
    _testAllApis();
  }

  Future<void> _testAllApis() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing all Philippine location APIs...';
    });

    final results = <String, dynamic>{};
    final workingApis = <String>[];
    final failedApis = <String>[];

    // Test Regions
    try {
      final regions = await LocationService.getRegions();
      results['regions'] = {
        'count': regions.length,
        'sample': regions.isNotEmpty ? regions.first : null,
        'status': 'success'
      };
      workingApis.add('Regions API');
    } catch (e) {
      results['regions'] = {
        'error': e.toString(),
        'status': 'failed'
      };
      failedApis.add('Regions API');
    }

    // Test Provinces for NCR
    try {
      final provinces = await LocationService.getProvinces('NCR');
      results['provinces'] = {
        'count': provinces.length,
        'sample': provinces.isNotEmpty ? provinces.first : null,
        'status': 'success'
      };
      workingApis.add('Provinces API');
    } catch (e) {
      results['provinces'] = {
        'error': e.toString(),
        'status': 'failed'
      };
      failedApis.add('Provinces API');
    }

    // Test Cities for Metro Manila
    try {
      final cities = await LocationService.getCities('NCR-001');
      results['cities'] = {
        'count': cities.length,
        'sample': cities.isNotEmpty ? cities.first : null,
        'status': 'success'
      };
      workingApis.add('Cities API');
    } catch (e) {
      results['cities'] = {
        'error': e.toString(),
        'status': 'failed'
      };
      failedApis.add('Cities API');
    }

    // Test Barangays for Manila
    try {
      final barangays = await LocationService.getBarangays('NCR-001-001');
      results['barangays'] = {
        'count': barangays.length,
        'sample': barangays.isNotEmpty ? barangays.first : null,
        'status': 'success'
      };
      workingApis.add('Barangays API');
    } catch (e) {
      results['barangays'] = {
        'error': e.toString(),
        'status': 'failed'
      };
      failedApis.add('Barangays API');
    }

    // Test Municipalities
    try {
      final municipalities = await LocationService.getMunicipalities('NCR-001');
      results['municipalities'] = {
        'count': municipalities.length,
        'sample': municipalities.isNotEmpty ? municipalities.first : null,
        'status': 'success'
      };
      workingApis.add('Municipalities API');
    } catch (e) {
      results['municipalities'] = {
        'error': e.toString(),
        'status': 'failed'
      };
      failedApis.add('Municipalities API');
    }

    setState(() {
      _results = results;
      _workingApis = workingApis;
      _failedApis = failedApis;
      _isLoading = false;
      _status = 'API Testing Complete!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprehensive API Test'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Philippine Location APIs Test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _workingApis.length > _failedApis.length ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _workingApis.length > _failedApis.length ? Colors.green : Colors.red,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _status,
                      style: TextStyle(
                        color: _workingApis.length > _failedApis.length ? Colors.green[800] : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Working APIs: ${_workingApis.length}'),
                    Text('Failed APIs: ${_failedApis.length}'),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // API Results
              const Text(
                'API Results:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final key = _results.keys.elementAt(index);
                    final result = _results[key];
                    final isSuccess = result['status'] == 'success';
                    
                    return Card(
                      color: isSuccess ? Colors.green[50] : Colors.red[50],
                      child: ListTile(
                        leading: Icon(
                          isSuccess ? Icons.check_circle : Icons.error,
                          color: isSuccess ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          key.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isSuccess) ...[
                              Text('Count: ${result['count']}'),
                              if (result['sample'] != null)
                                Text('Sample: ${result['sample']}'),
                            ] else ...[
                              Text('Error: ${result['error']}'),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Test Again Button
              ElevatedButton(
                onPressed: _testAllApis,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Test All APIs Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
