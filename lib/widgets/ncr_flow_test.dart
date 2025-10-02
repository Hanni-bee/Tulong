import 'package:flutter/material.dart';
import '../services/location_service.dart';

class NCRFlowTest extends StatefulWidget {
  const NCRFlowTest({super.key});

  @override
  State<NCRFlowTest> createState() => _NCRFlowTestState();
}

class _NCRFlowTestState extends State<NCRFlowTest> {
  String _status = 'Testing NCR flow...';
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];
  
  String? _selectedDistrict;
  String? _selectedCity;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNCRDistricts();
  }

  Future<void> _loadNCRDistricts() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading NCR districts...';
    });

    try {
      final districts = await LocationService.getProvinces('NCR');
      setState(() {
        _districts = districts;
        _isLoading = false;
        _status = '✅ Loaded ${districts.length} NCR districts';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = '❌ Error loading districts: $e';
      });
    }
  }

  Future<void> _loadCitiesFromDistrict(String districtName) async {
    setState(() {
      _isLoading = true;
      _status = 'Loading cities from district: $districtName';
      _selectedDistrict = districtName;
      _cities.clear();
      _barangays.clear();
    });

    try {
      final cities = await LocationService.getCities(districtName);
      setState(() {
        _cities = cities;
        _isLoading = false;
        _status = '✅ Loaded ${cities.length} cities from $districtName';
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
        title: const Text('NCR Flow Test'),
        backgroundColor: Colors.purple,
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
              // Districts
              const Text('NCR Districts:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                flex: 1,
                child: ListView.builder(
                  itemCount: _districts.length,
                  itemBuilder: (context, index) {
                    final district = _districts[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_city),
                        title: Text(district['name'] ?? 'Unknown'),
                        subtitle: Text('Code: ${district['code']}'),
                        onTap: () => _loadCitiesFromDistrict(district['name']),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Cities
              if (_selectedDistrict != null) ...[
                Text('Cities in $_selectedDistrict:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
