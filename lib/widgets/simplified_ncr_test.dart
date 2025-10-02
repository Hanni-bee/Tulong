import 'package:flutter/material.dart';
import '../services/location_service.dart';

class SimplifiedNCRTest extends StatefulWidget {
  const SimplifiedNCRTest({super.key});

  @override
  State<SimplifiedNCRTest> createState() => _SimplifiedNCRTestState();
}

class _SimplifiedNCRTestState extends State<SimplifiedNCRTest> {
  String _status = 'Testing simplified NCR flow...';
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];
  
  String? _selectedRegion;
  String? _selectedCity;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading regions (including NCR districts)...';
    });

    try {
      final regions = await LocationService.getRegions();
      setState(() {
        _regions = regions;
        _isLoading = false;
        _status = '✅ Loaded ${regions.length} regions (including NCR districts)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = '❌ Error loading regions: $e';
      });
    }
  }

  Future<void> _loadCitiesFromRegion(String regionName) async {
    setState(() {
      _isLoading = true;
      _status = 'Loading cities from region: $regionName';
      _selectedRegion = regionName;
      _cities.clear();
      _barangays.clear();
    });

    try {
      final cities = await LocationService.getProvinces(regionName);
      setState(() {
        _cities = cities;
        _isLoading = false;
        _status = '✅ Loaded ${cities.length} cities from $regionName';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = '❌ Error loading cities: $e';
      });
    }
  }

  Future<void> _loadBarangaysFromCity(String cityName) async {
    setState(() {
      _isLoading = true;
      _status = 'Loading barangays from city: $cityName';
      _selectedCity = cityName;
      _barangays.clear();
    });

    try {
      final barangays = await LocationService.getBarangays(cityName);
      setState(() {
        _barangays = barangays;
        _isLoading = false;
        _status = '✅ Loaded ${barangays.length} barangays from $cityName';
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
        title: const Text('Simplified NCR Test'),
        backgroundColor: Colors.orange,
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
              // Regions (including NCR districts)
              const Text('Regions (including NCR districts):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                flex: 1,
                child: ListView.builder(
                  itemCount: _regions.length,
                  itemBuilder: (context, index) {
                    final region = _regions[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          region['type'] == 'district' ? Icons.location_city : Icons.location_on,
                          color: region['type'] == 'district' ? Colors.orange : Colors.blue,
                        ),
                        title: Text(region['name'] ?? 'Unknown'),
                        subtitle: Text('Type: ${region['type']}'),
                        onTap: () => _loadCitiesFromRegion(region['name']),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Cities
              if (_selectedRegion != null) ...[
                Text('Cities in $_selectedRegion:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  flex: 1,
                  child: ListView.builder(
                    itemCount: _cities.length,
                    itemBuilder: (context, index) {
                      final city = _cities[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(city['name'] ?? 'Unknown'),
                          subtitle: Text('District: ${city['district']}'),
                          onTap: () => _loadBarangaysFromCity(city['name']),
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              const SizedBox(height: 10),
              
              // Barangays
              if (_selectedCity != null) ...[
                Text('Barangays in $_selectedCity:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  flex: 1,
                  child: ListView.builder(
                    itemCount: _barangays.length,
                    itemBuilder: (context, index) {
                      final barangay = _barangays[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.home),
                          title: Text(barangay['name'] ?? 'Unknown'),
                          subtitle: Text('City: ${barangay['city']}'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
