import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class LocationService {
  // Primary API - Reliable GitHub-hosted API
  static const String _githubApi = 'https://raw.githubusercontent.com/jdcbdev/ph-locations-api/main/data';
  
  // Backup API - Alternative reliable source  
  static const String _backupApi = 'https://api.github.com/repos/jdcbdev/ph-locations-api/contents/data';
  
  // Local JSON file for offline fallback
  static const String _localDataFile = 'assets/philippine_provinces_cities_municipalities_and_barangays_2019v2.json';
  
  static String _normalizeName(String s) {
    String r = s.toUpperCase().trim();
    r = r.replaceAll('CITY OF ', '');
    r = r.replaceAll(' CITY', '');
    r = r.replaceAll('Ñ', 'N');
    r = r.replaceAll(RegExp(r'[^A-Z0-9 ]'), '');
    r = r.replaceAll(RegExp(r'\s+'), ' ').trim();
    return r;
  }
  
  // Get all regions using reliable GitHub API
  static Future<List<Map<String, dynamic>>> getRegions() async {
    // First, try local JSON for reliable data
    try {
      print('🌐 Using local JSON for regions...');
      final String jsonString = await rootBundle.loadString(_localDataFile);
      final Map<String, dynamic> data = json.decode(jsonString);
      final List<Map<String, dynamic>> regions = [];

      // Add NCR districts first
      if (data.containsKey('NCR') && data['NCR'] is Map<String, dynamic>) {
        final ncrData = data['NCR'] as Map<String, dynamic>;
        if (ncrData.containsKey('province_list') && ncrData['province_list'] is Map<String, dynamic>) {
          (ncrData['province_list'] as Map<String, dynamic>).forEach((districtName, districtData) {
            regions.add({
              'code': districtName,
              'name': districtName,
              'regionCode': 'NCR',
              'type': 'district'
            });
          });
        }
      }

      // Add other regions
      data.forEach((key, value) {
        if (value is Map<String, dynamic> && key != 'NCR') {
          final regionName = _getRegionName(key);
          regions.add({
            'code': key,
            'name': regionName,
            'regionCode': key,
            'type': 'region'
          });
        }
      });

      print('✅ Local JSON: Loaded ${regions.length} regions (including NCR districts)');
      for (final region in regions.take(5)) {
        print('   - ${region['name']} (${region['code']})');
      }
      return regions;
    } catch (e) {
      print('❌ Local JSON failed for regions: $e');
    }

    // Fallback to GitHub API if local fails
    try {
      print('🌐 Trying GitHub API for regions...');
      final response = await http.get(
        Uri.parse('$_githubApi/regions.json'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      print('📡 GitHub regions response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final regions = data.map<Map<String, dynamic>>((r) => {
          'code': r['code']?.toString() ?? '',
          'name': r['name']?.toString() ?? '',
          'regionCode': r['code']?.toString() ?? '',
          'type': 'region',
        }).toList();
        print('✅ GitHub API: Loaded ${regions.length} regions');
        return regions;
      }
    } catch (e) {
      print('❌ GitHub API failed for regions: $e');
    }

    // Final fallback
    print('⚠️ All sources failed, using hardcoded regions');
    return getFallbackRegions();
  }

  // Helper method to get region name from code
  static String _getRegionName(String code) {
    final regionNames = {
      '01': 'Ilocos Region',
      '02': 'Cagayan Valley',
      '03': 'Central Luzon',
      '04A': 'CALABARZON',
      '04B': 'MIMAROPA',
      '05': 'Bicol Region',
      '06': 'Western Visayas',
      '07': 'Central Visayas',
      '08': 'Eastern Visayas',
      '09': 'Zamboanga Peninsula',
      '10': 'Northern Mindanao',
      '11': 'Davao Region',
      '12': 'SOCCSKSARGEN',
      '13': 'Caraga',
      '14': 'Cordillera Administrative Region',
      '15': 'Bangsamoro Autonomous Region in Muslim Mindanao',
      'NCR': 'National Capital Region',
    };
    return regionNames[code] ?? 'Region $code';
  }
  
  // Get provinces by region code - handle NCR districts specially
  static Future<List<Map<String, dynamic>>> getProvinces(String regionCode) async {
    // Special handling for NCR region
    final rcUpper = regionCode.toUpperCase();
    if (rcUpper.contains('NATIONAL CAPITAL REGION') || rcUpper == 'NCR') {
      print('🏙️ NCR region selected - returning list of NCR cities/districts');
      // Treat NCR as one "province" consisting of its cities/districts
      return await _getNCRCities();
    }

    // First, try local JSON for reliable province data
    try {
      print('🌐 Using local JSON for provinces in region $regionCode...');
      final String jsonString = await rootBundle.loadString(_localDataFile);
      final Map<String, dynamic> data = json.decode(jsonString);

      // Find the region in the data
      final regionData = data[regionCode];
      if (regionData != null && regionData is Map<String, dynamic>) {
        final List<Map<String, dynamic>> provinces = [];

        // Extract provinces from the province_list
        if (regionData.containsKey('province_list') && regionData['province_list'] is Map<String, dynamic>) {
          (regionData['province_list'] as Map<String, dynamic>).forEach((provinceName, provinceData) {
            provinces.add({
              'code': provinceName,
              'name': provinceName,
              'regionCode': regionCode,
            });
          });
        }

        if (provinces.isNotEmpty) {
          print('✅ Local JSON: Loaded ${provinces.length} provinces for region $regionCode');
          for (final province in provinces.take(3)) {
            print('   - ${province['name']} (${province['code']})');
          }
          return provinces;
        }
      }
    } catch (e) {
      print('❌ Local JSON failed for provinces: $e');
    }

    // Fallback to GitHub API if local fails
    try {
      const url = '$_githubApi/provinces.json';
      print('🌐 Trying GitHub API for provinces: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      print('📡 GitHub provinces response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final provinces = data.where((p) =>
          p['region_code']?.toString() == regionCode ||
          p['regionCode']?.toString() == regionCode
        ).map<Map<String, dynamic>>((p) => {
          'code': p['code']?.toString() ?? '',
          'name': p['name']?.toString() ?? '',
        }).toList();
        if (provinces.isNotEmpty) {
          print('✅ GitHub API: Loaded ${provinces.length} provinces for region $regionCode');
          return provinces;
        }
      }
    } catch (e) {
      print('❌ GitHub API provinces failed: $e');
    }

    // Final fallback
    print('⚠️ All sources failed, using hardcoded provinces for region $regionCode');
    return getFallbackProvinces(regionCode);
  }
  
  // Get cities by province code - handle NCR districts specially
  static Future<List<Map<String, dynamic>>> getCities(String provinceCode) async {
    // Special handling for NCR districts - get cities from specific district
    if (provinceCode.contains('NCR') || provinceCode.contains('NATIONAL CAPITAL REGION')) {
      print('🏙️ NCR district cities requested - getting cities from district: $provinceCode');
      return await _getNCRCitiesFromDistrict(provinceCode);
    }

    // First, try local JSON for reliable city data
    try {
      print('🌐 Using local JSON for cities in province $provinceCode...');
      final String jsonString = await rootBundle.loadString(_localDataFile);
      final Map<String, dynamic> data = json.decode(jsonString);

      // Find the region first
      String? regionCode;
      String? foundProvinceCode;

      // Search through all regions to find the province
      data.forEach((regionKey, regionValue) {
        if (regionValue is Map<String, dynamic> && regionValue.containsKey('province_list')) {
          final provinceList = regionValue['province_list'] as Map<String, dynamic>;
          if (provinceList.containsKey(provinceCode)) {
            regionCode = regionKey;
            foundProvinceCode = provinceCode;
          }
        }
      });

      if (regionCode != null && foundProvinceCode != null) {
        final regionData = data[regionCode];
        final provinceData = regionData['province_list'][foundProvinceCode];

        if (provinceData != null && provinceData is Map<String, dynamic>) {
          final List<Map<String, dynamic>> cities = [];

          // Extract cities from municipality_list
          if (provinceData.containsKey('municipality_list') && provinceData['municipality_list'] is Map<String, dynamic>) {
            (provinceData['municipality_list'] as Map<String, dynamic>).forEach((cityName, cityData) {
              cities.add({
                'code': cityName,
                'name': cityName,
                'provinceCode': foundProvinceCode,
                'regionCode': regionCode,
              });
            });
          }

          if (cities.isNotEmpty) {
            print('✅ Local JSON: Loaded ${cities.length} cities for province $provinceCode');
            for (final city in cities.take(3)) {
              print('   - ${city['name']} (${city['code']})');
            }
            return cities;
          }
        }
      }
    } catch (e) {
      print('❌ Local JSON failed for cities: $e');
    }

    // Fallback to GitHub API if local fails
    try {
      print('🌐 Trying GitHub API for cities in province $provinceCode...');
      final response = await http.get(
        Uri.parse('$_githubApi/cities.json'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      print('📡 GitHub cities response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final cities = data.where((c) =>
          c['province_code']?.toString() == provinceCode ||
          c['provinceCode']?.toString() == provinceCode
        ).map<Map<String, dynamic>>((c) => {
          'code': c['code']?.toString() ?? '',
          'name': c['name']?.toString() ?? '',
        }).toList();
        if (cities.isNotEmpty) {
          print('✅ GitHub API: Loaded ${cities.length} cities for province $provinceCode');
          return cities;
        }
      }
    } catch (e) {
      print('❌ GitHub API cities failed: $e');
    }

    // Final fallback
    print('⚠️ All sources failed, using hardcoded cities for province $provinceCode');
    return getFallbackCities(provinceCode);
  }

  // Get NCR districts from local JSON
  static Future<List<Map<String, dynamic>>> _getNCRDistricts() async {
    try {
      final String jsonString = await rootBundle.loadString(_localDataFile);
      final Map<String, dynamic> data = json.decode(jsonString);
      
      // Get NCR data
      final ncrData = data['NCR'];
      if (ncrData != null && ncrData['province_list'] != null) {
        final List<Map<String, dynamic>> districts = [];
        
        // Extract districts from NCR province_list
        (ncrData['province_list'] as Map<String, dynamic>).forEach((districtName, districtData) {
          districts.add({
            'code': districtName,
            'name': districtName,
            'regionCode': 'NCR',
            'type': 'district'
          });
        });
        
        print('✅ Local JSON: Loaded ${districts.length} NCR districts');
        return districts;
      }
    } catch (e) {
      print('❌ Local JSON failed for NCR districts: $e');
    }

    // Fallback to local NCR districts
    print('⚠️ Using local NCR districts data');
    return getFallbackNCRDistricts();
  }

  // Get NCR cities specifically
  static Future<List<Map<String, dynamic>>> _getNCRCities() async {
    try {
      final String jsonString = await rootBundle.loadString(_localDataFile);
      final Map<String, dynamic> data = json.decode(jsonString);
      
      // Get NCR data
      final ncrData = data['NCR'];
      if (ncrData != null && ncrData['province_list'] != null) {
        final List<Map<String, dynamic>> cities = [];
        
        // Extract cities from all NCR districts
        (ncrData['province_list'] as Map<String, dynamic>).forEach((districtName, districtData) {
          if (districtData['municipality_list'] != null) {
            (districtData['municipality_list'] as Map<String, dynamic>).forEach((cityName, cityData) {
              cities.add({
                'code': cityName,
                'name': cityName,
                'regionCode': 'NCR',
                'district': districtName,
                'type': 'city'
              });
            });
          }
        });
        
        print('✅ Local JSON: Loaded ${cities.length} NCR cities');
        return cities;
      }
    } catch (e) {
      print('❌ Local JSON failed for NCR cities: $e');
    }

    // Fallback to local NCR cities
    print('⚠️ Using local NCR cities data');
    return getFallbackNCRCities();
  }

  // Get NCR cities from specific district
  static Future<List<Map<String, dynamic>>> _getNCRCitiesFromDistrict(String districtName) async {
    try {
      final String jsonString = await rootBundle.loadString(_localDataFile);
      final Map<String, dynamic> data = json.decode(jsonString);
      
      // Get NCR data
      final ncrData = data['NCR'];
      if (ncrData != null && ncrData['province_list'] != null) {
        final List<Map<String, dynamic>> cities = [];
        
        // Find the specific district
        final districtData = ncrData['province_list'][districtName];
        if (districtData != null && districtData['municipality_list'] != null) {
          (districtData['municipality_list'] as Map<String, dynamic>).forEach((cityName, cityData) {
            cities.add({
              'code': cityName,
              'name': cityName,
              'regionCode': 'NCR',
              'district': districtName,
              'type': 'city'
            });
          });
        }
        
        print('✅ Local JSON: Loaded ${cities.length} cities from NCR district: $districtName');
        return cities;
      }
    } catch (e) {
      print('❌ Local JSON failed for NCR district cities: $e');
    }

    // Fallback to local NCR cities
    print('⚠️ Using local NCR cities data');
    return getFallbackNCRCities();
  }

  // Get barangays from NCR city
  static Future<List<Map<String, dynamic>>> _getNCRBarangaysFromCity(String cityName) async {
    try {
      final String jsonString = await rootBundle.loadString(_localDataFile);
      final Map<String, dynamic> data = json.decode(jsonString);
      
      // Get NCR data
      final ncrData = data['NCR'];
      if (ncrData != null && ncrData['province_list'] != null) {
        final List<Map<String, dynamic>> barangays = [];
        
        // Search through all districts to find the city
        (ncrData['province_list'] as Map<String, dynamic>).forEach((districtName, districtData) {
          if (districtData['municipality_list'] != null) {
            // Normalization helper to match variants like 'CITY OF X' vs 'X CITY'
            String normalize(String s) {
              String r = s.toUpperCase().trim();
              r = r.replaceAll('CITY OF ', '');
              r = r.replaceAll(' CITY', '');
              r = r.replaceAll('Ñ', 'N');
              r = r.replaceAll(RegExp(r'\s+'), ' ').trim();
              return r;
            }

            final String target = normalize(cityName);

            // Try direct key lookup with multiple variations first (fast path)
            final variations = <String>{
              cityName,
              'CITY OF ${cityName.replaceAll('CITY OF ', '')}',
              cityName.replaceAll('CITY OF ', ''),
              cityName.toUpperCase(),
              '${cityName.replaceAll('CITY OF ', '')} CITY',
              '${cityName.toUpperCase().replaceAll('CITY OF ', '')} CITY',
            };

            Map<String, dynamic>? cityData;
            String? matchedKey;
            for (final v in variations) {
              final candidate = districtData['municipality_list'][v];
              if (candidate != null) {
                cityData = candidate as Map<String, dynamic>;
                matchedKey = v;
                break;
              }
            }

            // If not found by key, scan keys and match by normalized form (robust path)
            if (cityData == null) {
              (districtData['municipality_list'] as Map<String, dynamic>).forEach((k, v) {
                if (cityData != null) return; // already found
                if (normalize(k) == target) {
                  cityData = v as Map<String, dynamic>;
                  matchedKey = k;
                }
              });
            }

            if (cityData != null && cityData!['barangay_list'] != null) {
              for (var barangayName in (cityData!['barangay_list'] as List<dynamic>)) {
                  barangays.add({
                    'code': barangayName,
                    'name': barangayName,
                    'regionCode': 'NCR',
                    'district': districtName,
                  'city': matchedKey ?? cityName,
                    'type': 'barangay'
                  });
              }
            }
          }
        });
        
        print('✅ Local JSON: Loaded ${barangays.length} barangays from NCR city: $cityName');
        return barangays;
      }
    } catch (e) {
      print('❌ Local JSON failed for NCR city barangays: $e');
    }

    // Fallback to local barangays
    print('⚠️ Using local barangays data');
    return getFallbackBarangays(cityName);
  }
  
  // Get barangays by city code using local JSON first
  static Future<List<Map<String, dynamic>>> getBarangays(String cityCode) async {
    // If the value looks like a city name (has letters/spaces), try local JSON path first
    if (cityCode.contains(RegExp(r'[A-Za-z]'))) {
      print('🏙️ Barangays requested by city name "$cityCode"');

      // 1) Try local JSON lookup first (faster and more reliable)
      try {
        print('🌐 Using local JSON for barangays in city "$cityCode"...');
        final String jsonString = await rootBundle.loadString(_localDataFile);
        final Map<String, dynamic> data = json.decode(jsonString);

        // Search through all regions and provinces to find the city
        for (final regionEntry in data.entries) {
          final regionKey = regionEntry.key;
          final regionValue = regionEntry.value;
          
          if (regionValue is Map<String, dynamic> && regionValue.containsKey('province_list')) {
            final provinceList = regionValue['province_list'] as Map<String, dynamic>;

            for (final provinceEntry in provinceList.entries) {
              final provinceName = provinceEntry.key;
              final provinceData = provinceEntry.value;
              
              if (provinceData is Map<String, dynamic> && provinceData.containsKey('municipality_list')) {
                final municipalityList = provinceData['municipality_list'] as Map<String, dynamic>;

                // Check if this city exists
                if (municipalityList.containsKey(cityCode)) {
                  final cityData = municipalityList[cityCode];
                  if (cityData is Map<String, dynamic> && cityData.containsKey('barangay_list')) {
                    final barangayList = cityData['barangay_list'] as List<dynamic>;
                    final barangays = barangayList.map<Map<String, dynamic>>((barangay) => {
                      'code': barangay.toString(),
                      'name': barangay.toString(),
                      'cityCode': cityCode,
                      'provinceCode': provinceName,
                      'regionCode': regionKey,
                    }).toList();

                    print('✅ Local JSON: Loaded ${barangays.length} barangays for city "$cityCode"');
                    return barangays;
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        print('❌ Local JSON failed for barangays: $e');
      }

      // 2) NCR local lookup as backup
      final ncrResult = await _getNCRBarangaysFromCity(cityCode);
      if (ncrResult.isNotEmpty) return ncrResult;

      // 3) Try GitHub API lookup by city name → get code(s) then fetch barangays
      try {
        print('🌐 Calling GitHub API for barangays in city "$cityCode"...');
        // First get all cities to find matching codes
        final citiesResponse = await http.get(
          Uri.parse('$_githubApi/cities.json'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10));
        print('📡 GitHub cities response status: ${citiesResponse.statusCode}');

        if (citiesResponse.statusCode == 200) {
          final List<dynamic> cities = json.decode(citiesResponse.body);
          final target = _normalizeName(cityCode);
          final matchedCodes = <String>[];

          for (final c in cities) {
            final name = (c['name'] ?? '').toString();
            final code = (c['code'] ?? '').toString();
            if (name.isNotEmpty && code.isNotEmpty && _normalizeName(name) == target) {
              matchedCodes.add(code);
            }
          }

          if (matchedCodes.isNotEmpty) {
            final results = <Map<String, dynamic>>[];
            for (final code in matchedCodes) {
              try {
                final r = await http.get(
                  Uri.parse('$_githubApi/barangays.json'),
                  headers: {'Accept': 'application/json'},
                ).timeout(const Duration(seconds: 10));
                print('📡 GitHub barangays response status: ${r.statusCode}');

                if (r.statusCode == 200) {
                  final List<dynamic> brgys = json.decode(r.body);
                  final cityBarangays = brgys.where((b) =>
                    b['city_code']?.toString() == code ||
                    b['cityCode']?.toString() == code
                  ).map<Map<String, dynamic>>((b) => {
                    'code': (b['code'] ?? '').toString(),
                    'name': (b['name'] ?? '').toString(),
                  }).toList();
                  results.addAll(cityBarangays);
                }
              } catch (_) {}
            }
            if (results.isNotEmpty) {
              print('✅ GitHub API: Loaded ${results.length} barangays for city "$cityCode"');
              return results;
            }
          }
        }
      } catch (e) {
        print('❌ GitHub API lookup by name failed: $e');
      }

    } else if (cityCode.contains('NCR')) {
      // If it's clearly an NCR code, try local JSON for speed
      final ncrResult = await _getNCRBarangaysFromCity(cityCode);
      if (ncrResult.isNotEmpty) return ncrResult;
    }

    // Final fallback
    print('⚠️ All sources failed, using hardcoded barangays for city $cityCode');
    return getFallbackBarangays(cityCode);
  }

  // Get municipalities by province code
  static Future<List<Map<String, dynamic>>> getMunicipalities(String provinceCode) async {
    try {
      final response = await http.get(
        Uri.parse('https://raw.githubusercontent.com/ajcanlas-tip/psgc-api/main/data/philippine_provinces_cities_municipalities_and_barangays_2019v2.json'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> municipalities = data['municipalities'] ?? [];
        // Filter municipalities by province code
        final filteredData = municipalities.where((municipality) => 
          municipality['provinceCode'] == provinceCode || 
          municipality['province_code'] == provinceCode ||
          municipality['province'] == provinceCode
        ).toList();
        return filteredData.cast<Map<String, dynamic>>();
      }
      print('API Error: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      print('Error fetching municipalities: $e');
      return [];
    }
  }

  // Get complete data structure for debugging
  static Future<Map<String, dynamic>?> getCompleteData() async {
    try {
      final response = await http.get(
        Uri.parse('https://raw.githubusercontent.com/ajcanlas-tip/psgc-api/main/data/philippine_provinces_cities_municipalities_and_barangays_2019v2.json'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Data structure keys: ${data.keys.toList()}');
        return data;
      }
      print('API Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error fetching complete data: $e');
      return null;
    }
  }
  
  // Fallback data for offline use
  static List<Map<String, dynamic>> getFallbackRegions() {
    return [
      {'code': 'NCR', 'name': 'National Capital Region (NCR)'},
      {'code': '01', 'name': 'Region I (Ilocos Region)'},
      {'code': '02', 'name': 'Region II (Cagayan Valley)'},
      {'code': '03', 'name': 'Region III (Central Luzon)'},
      {'code': '04A', 'name': 'Region IV-A (CALABARZON)'},
      {'code': '04B', 'name': 'Region IV-B (MIMAROPA)'},
      {'code': '05', 'name': 'Region V (Bicol Region)'},
      {'code': '06', 'name': 'Region VI (Western Visayas)'},
      {'code': '07', 'name': 'Region VII (Central Visayas)'},
      {'code': '08', 'name': 'Region VIII (Eastern Visayas)'},
      {'code': '09', 'name': 'Region IX (Zamboanga Peninsula)'},
      {'code': '10', 'name': 'Region X (Northern Mindanao)'},
      {'code': '11', 'name': 'Region XI (Davao Region)'},
      {'code': '12', 'name': 'Region XII (SOCCSKSARGEN)'},
      {'code': '13', 'name': 'Region XIII (Caraga)'},
      {'code': 'BARMM', 'name': 'Bangsamoro Autonomous Region in Muslim Mindanao (BARMM)'},
      {'code': 'CAR', 'name': 'Cordillera Administrative Region (CAR)'},
    ];
  }

  // Get fallback provinces for offline use
  static List<Map<String, dynamic>> getFallbackProvinces(String regionCode) {
    // Return comprehensive province data for offline use
    final Map<String, List<Map<String, dynamic>>> regionProvinces = {
      'NCR': [
        {'code': 'NATIONAL CAPITAL REGION - FIRST DISTRICT', 'name': 'NATIONAL CAPITAL REGION - FIRST DISTRICT'},
        {'code': 'NATIONAL CAPITAL REGION - SECOND DISTRICT', 'name': 'NATIONAL CAPITAL REGION - SECOND DISTRICT'},
        {'code': 'NATIONAL CAPITAL REGION - THIRD DISTRICT', 'name': 'NATIONAL CAPITAL REGION - THIRD DISTRICT'},
        {'code': 'NATIONAL CAPITAL REGION - FOURTH DISTRICT', 'name': 'NATIONAL CAPITAL REGION - FOURTH DISTRICT'},
      ],
      '01': [ // Ilocos Region
        {'code': 'ILOCOS NORTE', 'name': 'ILOCOS NORTE'},
        {'code': 'ILOCOS SUR', 'name': 'ILOCOS SUR'},
        {'code': 'LA UNION', 'name': 'LA UNION'},
        {'code': 'PANGASINAN', 'name': 'PANGASINAN'},
      ],
      '02': [ // Cagayan Valley
        {'code': 'BATANES', 'name': 'BATANES'},
        {'code': 'CAGAYAN', 'name': 'CAGAYAN'},
        {'code': 'ISABELA', 'name': 'ISABELA'},
        {'code': 'NUEVA VIZCAYA', 'name': 'NUEVA VIZCAYA'},
        {'code': 'QUIRINO', 'name': 'QUIRINO'},
      ],
      '03': [ // Central Luzon
        {'code': 'AURORA', 'name': 'AURORA'},
        {'code': 'BATAAN', 'name': 'BATAAN'},
        {'code': 'BULACAN', 'name': 'BULACAN'},
        {'code': 'NUEVA ECIJA', 'name': 'NUEVA ECIJA'},
        {'code': 'PAMPANGA', 'name': 'PAMPANGA'},
        {'code': 'TARLAC', 'name': 'TARLAC'},
        {'code': 'ZAMBALES', 'name': 'ZAMBALES'},
      ],
      '04A': [ // CALABARZON
        {'code': 'BATANGAS', 'name': 'BATANGAS'},
        {'code': 'CAVITE', 'name': 'CAVITE'},
        {'code': 'LAGUNA', 'name': 'LAGUNA'},
        {'code': 'QUEZON', 'name': 'QUEZON'},
        {'code': 'RIZAL', 'name': 'RIZAL'},
      ],
      '04B': [ // MIMAROPA
        {'code': 'MARINDUQUE', 'name': 'MARINDUQUE'},
        {'code': 'OCCIDENTAL MINDORO', 'name': 'OCCIDENTAL MINDORO'},
        {'code': 'ORIENTAL MINDORO', 'name': 'ORIENTAL MINDORO'},
        {'code': 'PALAWAN', 'name': 'PALAWAN'},
        {'code': 'ROMBLON', 'name': 'ROMBLON'},
      ],
    };
    
    return regionProvinces[regionCode] ?? [];
  }

  // Get fallback cities for offline use
  static List<Map<String, dynamic>> getFallbackCities(String provinceCode) {
    // Return comprehensive city data for offline use
    final Map<String, List<Map<String, dynamic>>> provinceCities = {
      'NCR-001': [ // Manila
        {'code': 'NCR-001-001', 'name': 'Binondo'},
        {'code': 'NCR-001-002', 'name': 'Ermita'},
        {'code': 'NCR-001-003', 'name': 'Intramuros'},
        {'code': 'NCR-001-004', 'name': 'Malate'},
        {'code': 'NCR-001-005', 'name': 'Paco'},
        {'code': 'NCR-001-006', 'name': 'Pandacan'},
        {'code': 'NCR-001-007', 'name': 'Port Area'},
        {'code': 'NCR-001-008', 'name': 'Quiapo'},
        {'code': 'NCR-001-009', 'name': 'Sampaloc'},
        {'code': 'NCR-001-010', 'name': 'San Andres'},
        {'code': 'NCR-001-011', 'name': 'San Miguel'},
        {'code': 'NCR-001-012', 'name': 'San Nicolas'},
        {'code': 'NCR-001-013', 'name': 'Santa Ana'},
        {'code': 'NCR-001-014', 'name': 'Santa Cruz'},
        {'code': 'NCR-001-015', 'name': 'Santa Mesa'},
        {'code': 'NCR-001-016', 'name': 'Tondo'},
      ],
      'NCR-002': [ // Quezon City
        {'code': 'NCR-002-001', 'name': 'Alicia'},
        {'code': 'NCR-002-002', 'name': 'Amihan'},
        {'code': 'NCR-002-003', 'name': 'Apolonio Samson'},
        {'code': 'NCR-002-004', 'name': 'Baesa'},
        {'code': 'NCR-002-005', 'name': 'Bagbag'},
        {'code': 'NCR-002-006', 'name': 'Bagong Silangan'},
        {'code': 'NCR-002-007', 'name': 'Bago Bantay'},
        {'code': 'NCR-002-008', 'name': 'Bahay Toro'},
        {'code': 'NCR-002-009', 'name': 'Balingasa'},
        {'code': 'NCR-002-010', 'name': 'Balintawak'},
        {'code': 'NCR-002-011', 'name': 'Balumbato'},
        {'code': 'NCR-002-012', 'name': 'Batasan Hills'},
        {'code': 'NCR-002-013', 'name': 'Bayantree'},
        {'code': 'NCR-002-014', 'name': 'Blue Ridge A'},
        {'code': 'NCR-002-015', 'name': 'Blue Ridge B'},
        {'code': 'NCR-002-016', 'name': 'Botocan'},
        {'code': 'NCR-002-017', 'name': 'Bungad'},
        {'code': 'NCR-002-018', 'name': 'Camp Aguinaldo'},
        {'code': 'NCR-002-019', 'name': 'Capri'},
        {'code': 'NCR-002-020', 'name': 'Central'},
        {'code': 'NCR-002-021', 'name': 'Claro'},
        {'code': 'NCR-002-022', 'name': 'Commonwealth'},
        {'code': 'NCR-002-023', 'name': 'Culiat'},
        {'code': 'NCR-002-024', 'name': 'Damar'},
        {'code': 'NCR-002-025', 'name': 'Damayan'},
        {'code': 'NCR-002-026', 'name': 'Damlag'},
        {'code': 'NCR-002-027', 'name': 'Damong Maliit'},
        {'code': 'NCR-002-028', 'name': 'Del Monte'},
        {'code': 'NCR-002-029', 'name': 'Diliman'},
        {'code': 'NCR-002-030', 'name': 'Dioquino Zobel'},
        {'code': 'NCR-002-031', 'name': 'Don Manuel'},
        {'code': 'NCR-002-032', 'name': 'Doña Aurora'},
        {'code': 'NCR-002-033', 'name': 'Doña Faustina'},
        {'code': 'NCR-002-034', 'name': 'Doña Imelda'},
        {'code': 'NCR-002-035', 'name': 'Doña Josefa'},
        {'code': 'NCR-002-036', 'name': 'Duyan-Duyan'},
        {'code': 'NCR-002-037', 'name': 'E. Rodriguez'},
        {'code': 'NCR-002-038', 'name': 'East Kamias'},
        {'code': 'NCR-002-039', 'name': 'Escopa I'},
        {'code': 'NCR-002-040', 'name': 'Escopa II'},
        {'code': 'NCR-002-041', 'name': 'Escopa III'},
        {'code': 'NCR-002-042', 'name': 'Escopa IV'},
        {'code': 'NCR-002-043', 'name': 'Fairview'},
        {'code': 'NCR-002-044', 'name': 'Greater Lagro'},
        {'code': 'NCR-002-045', 'name': 'Gulod'},
        {'code': 'NCR-002-046', 'name': 'Holy Spirit'},
        {'code': 'NCR-002-047', 'name': 'Horseshoe'},
        {'code': 'NCR-002-048', 'name': 'Immaculate Conception'},
        {'code': 'NCR-002-049', 'name': 'Kaligayahan'},
        {'code': 'NCR-002-050', 'name': 'Kalusugan'},
        {'code': 'NCR-002-051', 'name': 'Kamuning'},
        {'code': 'NCR-002-052', 'name': 'Katipunan'},
        {'code': 'NCR-002-053', 'name': 'Kaunlaran'},
        {'code': 'NCR-002-054', 'name': 'Kristong Hari'},
        {'code': 'NCR-002-055', 'name': 'Krus na Ligas'},
        {'code': 'NCR-002-056', 'name': 'Laging Handa'},
        {'code': 'NCR-002-057', 'name': 'Libis'},
        {'code': 'NCR-002-058', 'name': 'Lourdes'},
        {'code': 'NCR-002-059', 'name': 'Loyola Heights'},
        {'code': 'NCR-002-060', 'name': 'Maharlika'},
        {'code': 'NCR-002-061', 'name': 'Malaya'},
        {'code': 'NCR-002-062', 'name': 'Mangga'},
        {'code': 'NCR-002-063', 'name': 'Manresa'},
        {'code': 'NCR-002-064', 'name': 'Mariana'},
        {'code': 'NCR-002-065', 'name': 'Mariblo'},
        {'code': 'NCR-002-066', 'name': 'Marilag'},
        {'code': 'NCR-002-067', 'name': 'Masagana'},
        {'code': 'NCR-002-068', 'name': 'Masambong'},
        {'code': 'NCR-002-069', 'name': 'Matalahib'},
        {'code': 'NCR-002-070', 'name': 'Matandang Balara'},
        {'code': 'NCR-002-071', 'name': 'Milagrosa'},
        {'code': 'NCR-002-072', 'name': 'Nagkaisang Nayon'},
        {'code': 'NCR-002-073', 'name': 'Nayong Kanluran'},
        {'code': 'NCR-002-074', 'name': 'New Era'},
        {'code': 'NCR-002-075', 'name': 'Novaliches Proper'},
        {'code': 'NCR-002-076', 'name': 'Obrero'},
        {'code': 'NCR-002-077', 'name': 'Old Capitol Site'},
        {'code': 'NCR-002-078', 'name': 'Paang Bundok'},
        {'code': 'NCR-002-079', 'name': 'Pag-asa'},
        {'code': 'NCR-002-080', 'name': 'Paligsahan'},
        {'code': 'NCR-002-081', 'name': 'Paltok'},
        {'code': 'NCR-002-082', 'name': 'Pansol'},
        {'code': 'NCR-002-083', 'name': 'Paraiso'},
        {'code': 'NCR-002-084', 'name': 'Pasong Putik Proper'},
        {'code': 'NCR-002-085', 'name': 'Pasong Tamo'},
        {'code': 'NCR-002-086', 'name': 'Payatas'},
        {'code': 'NCR-002-087', 'name': 'Phil-Am'},
        {'code': 'NCR-002-088', 'name': 'Pinagkaisahan'},
        {'code': 'NCR-002-089', 'name': 'Pinyahan'},
        {'code': 'NCR-002-090', 'name': 'Project 1'},
        {'code': 'NCR-002-091', 'name': 'Project 2'},
        {'code': 'NCR-002-092', 'name': 'Project 3'},
        {'code': 'NCR-002-093', 'name': 'Project 4'},
        {'code': 'NCR-002-094', 'name': 'Project 5'},
        {'code': 'NCR-002-095', 'name': 'Project 6'},
        {'code': 'NCR-002-096', 'name': 'Project 7'},
        {'code': 'NCR-002-097', 'name': 'Project 8'},
        {'code': 'NCR-002-098', 'name': 'Quezon City'},
        {'code': 'NCR-002-099', 'name': 'Quirino 2-A'},
        {'code': 'NCR-002-100', 'name': 'Quirino 2-B'},
        {'code': 'NCR-002-101', 'name': 'Quirino 2-C'},
        {'code': 'NCR-002-102', 'name': 'Quirino 3-A'},
        {'code': 'NCR-002-103', 'name': 'Ramon Magsaysay'},
        {'code': 'NCR-002-104', 'name': 'Roxas'},
        {'code': 'NCR-002-105', 'name': 'Sacred Heart'},
        {'code': 'NCR-002-106', 'name': 'Saint Peter'},
        {'code': 'NCR-002-107', 'name': 'Salvacion'},
        {'code': 'NCR-002-108', 'name': 'San Agustin'},
        {'code': 'NCR-002-109', 'name': 'San Antonio'},
        {'code': 'NCR-002-110', 'name': 'San Bartolome'},
        {'code': 'NCR-002-111', 'name': 'San Isidro'},
        {'code': 'NCR-002-112', 'name': 'San Isidro Labrador'},
        {'code': 'NCR-002-113', 'name': 'San Jose'},
        {'code': 'NCR-002-114', 'name': 'San Martin de Porres'},
        {'code': 'NCR-002-115', 'name': 'San Roque'},
        {'code': 'NCR-002-116', 'name': 'San Vicente'},
        {'code': 'NCR-002-117', 'name': 'Sangandaan'},
        {'code': 'NCR-002-118', 'name': 'Santa Cruz'},
        {'code': 'NCR-002-119', 'name': 'Santa Lucia'},
        {'code': 'NCR-002-120', 'name': 'Santa Monica'},
        {'code': 'NCR-002-121', 'name': 'Santa Teresita'},
        {'code': 'NCR-002-122', 'name': 'Santo Cristo'},
        {'code': 'NCR-002-123', 'name': 'Santo Domingo'},
        {'code': 'NCR-002-124', 'name': 'Santo Niño'},
        {'code': 'NCR-002-125', 'name': 'Santol'},
        {'code': 'NCR-002-126', 'name': 'Sauyo'},
        {'code': 'NCR-002-127', 'name': 'Sienna'},
        {'code': 'NCR-002-128', 'name': 'Sikatuna Village'},
        {'code': 'NCR-002-129', 'name': 'Silangan'},
        {'code': 'NCR-002-130', 'name': 'Socorro'},
        {'code': 'NCR-002-131', 'name': 'South Triangle'},
        {'code': 'NCR-002-132', 'name': 'Tagumpay'},
        {'code': 'NCR-002-133', 'name': 'Talayan'},
        {'code': 'NCR-002-134', 'name': 'Talipapa'},
        {'code': 'NCR-002-135', 'name': 'Tandang Sora'},
        {'code': 'NCR-002-136', 'name': 'Tatalon'},
        {'code': 'NCR-002-137', 'name': 'Teachers Village East'},
        {'code': 'NCR-002-138', 'name': 'Teachers Village West'},
        {'code': 'NCR-002-139', 'name': 'Ugong Norte'},
        {'code': 'NCR-002-140', 'name': 'Unang Sigaw'},
        {'code': 'NCR-002-141', 'name': 'University of the Philippines'},
        {'code': 'NCR-002-142', 'name': 'Valencia'},
        {'code': 'NCR-002-143', 'name': 'Vasra'},
        {'code': 'NCR-002-144', 'name': 'Veterans Village'},
        {'code': 'NCR-002-145', 'name': 'Villa Maria Clara'},
        {'code': 'NCR-002-146', 'name': 'West Kamias'},
        {'code': 'NCR-002-147', 'name': 'West Triangle'},
        {'code': 'NCR-002-148', 'name': 'White Plains'},
      ],
    };
    
    return provinceCities[provinceCode] ?? [];
  }

  // Get fallback barangays for offline use
  static List<Map<String, dynamic>> getFallbackBarangays(String cityCode) {
    // Return comprehensive barangay data for offline use
    final Map<String, List<Map<String, dynamic>>> cityBarangays = {
      'NCR-001-001': [ // Binondo
        {'code': 'NCR-001-001-001', 'name': 'Barangay 1'},
        {'code': 'NCR-001-001-002', 'name': 'Barangay 2'},
        {'code': 'NCR-001-001-003', 'name': 'Barangay 3'},
        {'code': 'NCR-001-001-004', 'name': 'Barangay 4'},
        {'code': 'NCR-001-001-005', 'name': 'Barangay 5'},
        {'code': 'NCR-001-001-006', 'name': 'Barangay 6'},
        {'code': 'NCR-001-001-007', 'name': 'Barangay 7'},
        {'code': 'NCR-001-001-008', 'name': 'Barangay 8'},
        {'code': 'NCR-001-001-009', 'name': 'Barangay 9'},
        {'code': 'NCR-001-001-010', 'name': 'Barangay 10'},
      ],
      'NCR-002-001': [ // Alicia, Quezon City
        {'code': 'NCR-002-001-001', 'name': 'Alicia Village'},
        {'code': 'NCR-002-001-002', 'name': 'Alicia Proper'},
        {'code': 'NCR-002-001-003', 'name': 'Alicia Heights'},
        {'code': 'NCR-002-001-004', 'name': 'Alicia Extension'},
        {'code': 'NCR-002-001-005', 'name': 'Alicia Subdivision'},
      ],
      'NCR-002-002': [ // Amihan, Quezon City
        {'code': 'NCR-002-002-001', 'name': 'Amihan Proper'},
        {'code': 'NCR-002-002-002', 'name': 'Amihan Extension'},
        {'code': 'NCR-002-002-003', 'name': 'Amihan Heights'},
        {'code': 'NCR-002-002-004', 'name': 'Amihan Village'},
      ],
    };
    
    return cityBarangays[cityCode] ?? [];
  }

  // Fallback NCR districts data - matches actual JSON structure
  static List<Map<String, dynamic>> getFallbackNCRDistricts() {
      return [
      {'code': 'NATIONAL CAPITAL REGION - FIRST DISTRICT', 'name': 'NATIONAL CAPITAL REGION - FIRST DISTRICT', 'regionCode': 'NCR'},
      {'code': 'NATIONAL CAPITAL REGION - SECOND DISTRICT', 'name': 'NATIONAL CAPITAL REGION - SECOND DISTRICT', 'regionCode': 'NCR'},
      {'code': 'NATIONAL CAPITAL REGION - THIRD DISTRICT', 'name': 'NATIONAL CAPITAL REGION - THIRD DISTRICT', 'regionCode': 'NCR'},
      {'code': 'NATIONAL CAPITAL REGION - FOURTH DISTRICT', 'name': 'NATIONAL CAPITAL REGION - FOURTH DISTRICT', 'regionCode': 'NCR'},
    ];
  }

  // Fallback NCR cities data - matches actual JSON structure
  static List<Map<String, dynamic>> getFallbackNCRCities() {
      return [
      {'code': 'CITY OF MANILA', 'name': 'CITY OF MANILA', 'regionCode': 'NCR'},
      {'code': 'CITY OF QUEZON', 'name': 'CITY OF QUEZON', 'regionCode': 'NCR'},
      {'code': 'CITY OF CALOOCAN', 'name': 'CITY OF CALOOCAN', 'regionCode': 'NCR'},
      {'code': 'CITY OF LAS PIÑAS', 'name': 'CITY OF LAS PIÑAS', 'regionCode': 'NCR'},
      {'code': 'CITY OF MAKATI', 'name': 'CITY OF MAKATI', 'regionCode': 'NCR'},
      {'code': 'CITY OF MALABON', 'name': 'CITY OF MALABON', 'regionCode': 'NCR'},
      {'code': 'CITY OF MANDALUYONG', 'name': 'CITY OF MANDALUYONG', 'regionCode': 'NCR'},
      {'code': 'CITY OF MARIKINA', 'name': 'CITY OF MARIKINA', 'regionCode': 'NCR'},
      {'code': 'CITY OF MUNTINLUPA', 'name': 'CITY OF MUNTINLUPA', 'regionCode': 'NCR'},
      {'code': 'CITY OF NAVOTAS', 'name': 'CITY OF NAVOTAS', 'regionCode': 'NCR'},
      {'code': 'CITY OF PARAÑAQUE', 'name': 'CITY OF PARAÑAQUE', 'regionCode': 'NCR'},
      {'code': 'CITY OF PASAY', 'name': 'CITY OF PASAY', 'regionCode': 'NCR'},
      {'code': 'CITY OF PASIG', 'name': 'CITY OF PASIG', 'regionCode': 'NCR'},
      {'code': 'CITY OF PATEROS', 'name': 'CITY OF PATEROS', 'regionCode': 'NCR'},
      {'code': 'CITY OF SAN JUAN', 'name': 'CITY OF SAN JUAN', 'regionCode': 'NCR'},
      {'code': 'CITY OF TAGUIG', 'name': 'CITY OF TAGUIG', 'regionCode': 'NCR'},
      {'code': 'CITY OF VALENZUELA', 'name': 'CITY OF VALENZUELA', 'regionCode': 'NCR'},
    ];
  }

}


