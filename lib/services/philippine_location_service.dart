import 'dart:convert';
import 'package:flutter/services.dart';

class PhilippineLocationService {
  static PhilippineLocationService? _instance;
  static PhilippineLocationService get instance {
    _instance ??= PhilippineLocationService._internal();
    return _instance!;
  }

  PhilippineLocationService._internal();

  Map<String, dynamic>? _locationData;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized && _locationData != null) {
      return;
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/philippine_provinces_cities_municipalities_and_barangays_2019v2.json');
      _locationData = json.decode(jsonString);
      _isInitialized = true;
    } catch (e) {
      print('PhilippineLocationService: ERROR loading location data: $e');
      print('PhilippineLocationService: Make sure the JSON file exists in assets/ and is declared in pubspec.yaml');
      _isInitialized = false;
      rethrow;
    }
  }

  List<String> getRegions() {
    if (_locationData == null) return [];

    return _locationData!.keys.map((key) {
      final region = _locationData![key] as Map<String, dynamic>;
      return region['region_name'] as String;
    }).toList()..sort();
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

  List<String> getBarangaysForCity(String regionName, String provinceName, String cityName) {
    if (_locationData == null) return [];
    
    for (final regionKey in _locationData!.keys) {
      final region = _locationData![regionKey] as Map<String, dynamic>;
      if (region['region_name'] == regionName) {
        final provinceList = region['province_list'] as Map<String, dynamic>;
        if (provinceList.containsKey(provinceName)) {
          final province = provinceList[provinceName] as Map<String, dynamic>;
          final municipalityList = province['municipality_list'] as Map<String, dynamic>;
          if (municipalityList.containsKey(cityName)) {
            final city = municipalityList[cityName] as Map<String, dynamic>;
            final barangayList = city['barangay_list'] as List<dynamic>;
            return barangayList.map((e) => e.toString()).toList();
          }
        }
      }
    }
    return [];
  }

  String getRegionKey(String regionName) {
    if (_locationData == null) return '';
    
    for (final regionKey in _locationData!.keys) {
      final region = _locationData![regionKey] as Map<String, dynamic>;
      if (region['region_name'] == regionName) {
        return regionKey;
      }
    }
    return '';
  }
}
