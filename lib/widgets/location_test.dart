import 'package:flutter/material.dart';
import '../services/location_service.dart';

class LocationTest extends StatefulWidget {
  const LocationTest({super.key});

  @override
  State<LocationTest> createState() => _LocationTestState();
}

class _LocationTestState extends State<LocationTest> {
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];
  
  String? _selectedRegion;
  String? _selectedProvince;
  String? _selectedCity;
  String? _selectedBarangay;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _debugDataStructure();
  }

  Future<void> _debugDataStructure() async {
    try {
      final data = await LocationService.getCompleteData();
      if (data != null) {
        print('Available data sections: ${data.keys.toList()}');
        if (data.containsKey('regions')) {
          print('Regions count: ${(data['regions'] as List).length}');
        }
        if (data.containsKey('provinces')) {
          print('Provinces count: ${(data['provinces'] as List).length}');
        }
        if (data.containsKey('cities')) {
          print('Cities count: ${(data['cities'] as List).length}');
        }
        if (data.containsKey('municipalities')) {
          print('Municipalities count: ${(data['municipalities'] as List).length}');
        }
        if (data.containsKey('barangays')) {
          print('Barangays count: ${(data['barangays'] as List).length}');
        }
      }
    } catch (e) {
      print('Error debugging data structure: $e');
    }
  }

  Future<void> _loadRegions() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final regions = await LocationService.getRegions();
      setState(() {
        _regions = regions;
        _isLoading = false;
      });
      print('Loaded ${regions.length} regions');
    } catch (e) {
      print('Error loading regions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProvinces(String regionCode) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final provinces = await LocationService.getProvinces(regionCode);
      setState(() {
        _provinces = provinces;
        _isLoading = false;
      });
      print('Loaded ${provinces.length} provinces for region $regionCode');
    } catch (e) {
      print('Error loading provinces: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCities(String provinceCode) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final cities = await LocationService.getCities(provinceCode);
      setState(() {
        _cities = cities;
        _isLoading = false;
      });
      print('Loaded ${cities.length} cities for province $provinceCode');
    } catch (e) {
      print('Error loading cities: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBarangays(String cityCode) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final barangays = await LocationService.getBarangays(cityCode);
      setState(() {
        _barangays = barangays;
        _isLoading = false;
      });
      print('Loaded ${barangays.length} barangays for city $cityCode');
    } catch (e) {
      print('Error loading barangays: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location API Test'),
        backgroundColor: Colors.red,
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
              // Region Dropdown
              const Text('Region:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedRegion,
                isExpanded: true,
                items: _regions.map((region) {
                  return DropdownMenuItem<String>(
                    value: region['code'],
                    child: Text(region['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRegion = value;
                    _selectedProvince = null;
                    _selectedCity = null;
                    _selectedBarangay = null;
                    _provinces.clear();
                    _cities.clear();
                    _barangays.clear();
                  });
                  if (value != null) {
                    _loadProvinces(value);
                  }
                },
                hint: const Text('Select Region'),
              ),
              
              const SizedBox(height: 20),
              
              // Province Dropdown
              const Text('Province:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedProvince,
                isExpanded: true,
                items: _provinces.map((province) {
                  return DropdownMenuItem<String>(
                    value: province['code'],
                    child: Text(province['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProvince = value;
                    _selectedCity = null;
                    _selectedBarangay = null;
                    _cities.clear();
                    _barangays.clear();
                  });
                  if (value != null) {
                    _loadCities(value);
                  }
                },
                hint: const Text('Select Province'),
              ),
              
              const SizedBox(height: 20),
              
              // City Dropdown
              const Text('City:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedCity,
                isExpanded: true,
                items: _cities.map((city) {
                  return DropdownMenuItem<String>(
                    value: city['code'],
                    child: Text(city['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCity = value;
                    _selectedBarangay = null;
                    _barangays.clear();
                  });
                  if (value != null) {
                    _loadBarangays(value);
                  }
                },
                hint: const Text('Select City'),
              ),
              
              const SizedBox(height: 20),
              
              // Barangay Dropdown
              const Text('Barangay:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedBarangay,
                isExpanded: true,
                items: _barangays.map((barangay) {
                  return DropdownMenuItem<String>(
                    value: barangay['code'],
                    child: Text(barangay['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBarangay = value;
                  });
                },
                hint: const Text('Select Barangay'),
              ),
              
              const SizedBox(height: 20),
              
              // Debug Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Regions: ${_regions.length}'),
                    Text('Provinces: ${_provinces.length}'),
                    Text('Cities: ${_cities.length}'),
                    Text('Barangays: ${_barangays.length}'),
                    if (_selectedRegion != null) Text('Selected Region: $_selectedRegion'),
                    if (_selectedProvince != null) Text('Selected Province: $_selectedProvince'),
                    if (_selectedCity != null) Text('Selected City: $_selectedCity'),
                    if (_selectedBarangay != null) Text('Selected Barangay: $_selectedBarangay'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
