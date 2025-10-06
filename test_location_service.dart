import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('Testing Philippine Location Service...');

  try {
    final service = PhilippineLocationService();
    await service.loadData();

    final regions = service.getRegions();
    print('✅ Successfully loaded ${regions.length} regions');

    if (regions.isNotEmpty) {
      print('✅ First few regions: ${regions.take(5).join(', ')}');

      // Test getting provinces for first region
      final firstRegion = regions.first;
      final provinces = service.getProvincesForRegion(firstRegion);
      print('✅ Provinces in $firstRegion: ${provinces.length}');

      if (provinces.isNotEmpty) {
        final firstProvince = provinces.first;
        final cities = service.getCitiesForProvince(firstRegion, firstProvince);
        print('✅ Cities in $firstProvince: ${cities.length}');
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

class PhilippineLocationService {
  static final PhilippineLocationService _instance = PhilippineLocationService._internal();
  factory PhilippineLocationService() => _instance;
  PhilippineLocationService._internal();

  Map<String, dynamic>? _locationData;
  bool _isLoaded = false;

  Future<void> loadData() async {
    if (_isLoaded && _locationData != null) return;

    try {
      final String jsonString = await rootBundle.loadString('assets/philippine_provinces_cities_municipalities_and_barangays_2019v2.json');
      _locationData = json.decode(jsonString);
      _isLoaded = true;
      print('✅ Philippine location data loaded successfully');
    } catch (e) {
      print('❌ Error loading Philippine location data: $e');
      _isLoaded = false;
      rethrow;
    }
  }

  List<String> getRegions() {
    if (_locationData == null) {
      print('❌ Location data not loaded yet');
      return [];
    }

    final regions = _locationData!.keys.map((key) {
      final region = _locationData![key] as Map<String, dynamic>;
      return region['region_name'] as String;
    }).toList()..sort();

    print('✅ Loaded ${regions.length} regions');
    return regions;
  }

  List<String> getProvincesForRegion(String regionName) {
    if (_locationData == null) return [];

    for (final regionKey in _locationData!.keys) {
      final region = _locationData![regionKey] as Map<String, dynamic>;
      if (region['region_name'] == regionName) {
        final provinceList = region['province_list'] as Map<String, dynamic>;
        return provinceList.keys.toList();
      }
    }
    return [];
  }

  List<String> getCitiesForProvince(String regionName, String provinceName) {
    if (_locationData == null) return [];

    for (final regionKey in _locationData!.keys) {
      final region = _locationData![regionKey] as Map<String, dynamic>;
      if (region['region_name'] == regionName) {
        final provinceList = region['province_list'] as Map<String, dynamic>;
        if (provinceList.containsKey(provinceName)) {
          final province = provinceList[provinceName] as Map<String, dynamic>;
          final municipalityList = province['municipality_list'] as Map<String, dynamic>;
          return municipalityList.keys.toList();
        }
      }
    }
    return [];
  }
}
