import 'dart:convert';
import 'package:flutter/services.dart';

class LocationService {
  // Primary API - Reliable GitHub-hosted API
  static const String _githubApi = 'https://raw.githubusercontent.com/jdcbdev/ph-locations-api/main/data';
  
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
  
  // Get all regions using local JSON
  static Future<List<Map<String, dynamic>>> getRegions() async {
    // Try local JSON for reliable data
    try {
      print('🌐 Using local JSON for regions...');
      final String jsonString = await rootBundle.loadString(_localDataFile);
      final Map<String, dynamic> data = json.decode(jsonString);
      final List<Map<String, dynamic>> regions = [];

      // Process all regions from the JSON
      data.forEach((regionCode, regionData) {
        if (regionData is Map<String, dynamic> && regionData.containsKey('region_name')) {
          final regionName = regionData['region_name'] as String;
          regions.add({
            'region_code': regionCode,
            'region_name': regionName,
            'code': regionCode,
            'name': regionName,
          });
        }
      });

      print('✅ Local JSON: Loaded ${regions.length} regions');
      for (final region in regions.take(5)) {
        print('   - ${region['name']} (${region['code']})');
      }
      return regions;
    } catch (e) {
      print('❌ Local JSON failed for regions: $e');
    }

    // Fallback to hardcoded regions
    print('⚠️ All sources failed, using hardcoded regions');
    return getFallbackRegions();
  }

  // Get provinces by region code
  static Future<List<Map<String, dynamic>>> getProvinces(String regionCode) async {
    // Try local JSON for reliable province data
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
              'province_code': provinceName,
              'province_name': provinceName,
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

    // Fallback to hardcoded provinces
    print('⚠️ All sources failed, using hardcoded provinces for region $regionCode');
    return getFallbackProvinces(regionCode);
  }
  
  // Get cities by province code
  static Future<List<Map<String, dynamic>>> getCities(String provinceCode) async {
    // Try local JSON for reliable city data
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
                'city_code': cityName,
                'city_name': cityName,
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

    // Fallback to hardcoded cities
    print('⚠️ All sources failed, using hardcoded cities for province $provinceCode');
    return getFallbackCities(provinceCode);
  }
  
  // Get barangays by city code using local JSON first
  static Future<List<Map<String, dynamic>>> getBarangays(String cityCode) async {
      print('🏙️ Barangays requested by city name "$cityCode"');

    // Try local JSON lookup first (faster and more reliable)
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
                    'brgy_code': barangay.toString(),
                    'brgy_name': barangay.toString(),
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

    // Final fallback
    print('⚠️ All sources failed, using hardcoded barangays for city $cityCode');
    return getFallbackBarangays(cityCode);
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
      'ILOCOS NORTE': [
        {'code': 'ADAMS', 'name': 'ADAMS'},
        {'code': 'BACARRA', 'name': 'BACARRA'},
        {'code': 'BADOC', 'name': 'BADOC'},
        {'code': 'BANGUI', 'name': 'BANGUI'},
        {'code': 'BATAC', 'name': 'BATAC'},
        {'code': 'BURGOS', 'name': 'BURGOS'},
        {'code': 'CARASI', 'name': 'CARASI'},
        {'code': 'CURRIMAO', 'name': 'CURRIMAO'},
        {'code': 'DINGRAS', 'name': 'DINGRAS'},
        {'code': 'DUMALNEG', 'name': 'DUMALNEG'},
        {'code': 'LAOAG CITY', 'name': 'LAOAG CITY'},
        {'code': 'MARCOS', 'name': 'MARCOS'},
        {'code': 'NUEVA ERA', 'name': 'NUEVA ERA'},
        {'code': 'PAGUDPUD', 'name': 'PAGUDPUD'},
        {'code': 'PAOAY', 'name': 'PAOAY'},
        {'code': 'PASUQUIN', 'name': 'PASUQUIN'},
        {'code': 'PIDDIG', 'name': 'PIDDIG'},
        {'code': 'PINILI', 'name': 'PINILI'},
        {'code': 'SAN NICOLAS', 'name': 'SAN NICOLAS'},
        {'code': 'SARRAT', 'name': 'SARRAT'},
        {'code': 'SOLSONA', 'name': 'SOLSONA'},
        {'code': 'VINTAR', 'name': 'VINTAR'},
      ],
      'BATANGAS': [
        {'code': 'AGONCILLO', 'name': 'AGONCILLO'},
        {'code': 'ALITAGTAG', 'name': 'ALITAGTAG'},
        {'code': 'BALAYAN', 'name': 'BALAYAN'},
        {'code': 'BALETE', 'name': 'BALETE'},
        {'code': 'BATANGAS CITY', 'name': 'BATANGAS CITY'},
        {'code': 'BAUAN', 'name': 'BAUAN'},
        {'code': 'CALACA', 'name': 'CALACA'},
        {'code': 'CALATAGAN', 'name': 'CALATAGAN'},
        {'code': 'CUENCA', 'name': 'CUENCA'},
        {'code': 'IBAAN', 'name': 'IBAAN'},
        {'code': 'LAUREL', 'name': 'LAUREL'},
        {'code': 'LEMERY', 'name': 'LEMERY'},
        {'code': 'LIAN', 'name': 'LIAN'},
        {'code': 'LIPA CITY', 'name': 'LIPA CITY'},
        {'code': 'LOBO', 'name': 'LOBO'},
        {'code': 'MABINI', 'name': 'MABINI'},
        {'code': 'MALVAR', 'name': 'MALVAR'},
        {'code': 'MATAASNAKAHOY', 'name': 'MATAASNAKAHOY'},
        {'code': 'NASUGBU', 'name': 'NASUGBU'},
        {'code': 'PADRE GARCIA', 'name': 'PADRE GARCIA'},
        {'code': 'ROSARIO', 'name': 'ROSARIO'},
        {'code': 'SAN JOSE', 'name': 'SAN JOSE'},
        {'code': 'SAN JUAN', 'name': 'SAN JUAN'},
        {'code': 'SAN LUIS', 'name': 'SAN LUIS'},
        {'code': 'SAN NICOLAS', 'name': 'SAN NICOLAS'},
        {'code': 'SAN PASCUAL', 'name': 'SAN PASCUAL'},
        {'code': 'SANTA TERESITA', 'name': 'SANTA TERESITA'},
        {'code': 'SANTO TOMAS', 'name': 'SANTO TOMAS'},
        {'code': 'TAAL', 'name': 'TAAL'},
        {'code': 'TALISAY', 'name': 'TALISAY'},
        {'code': 'TANAUAN CITY', 'name': 'TANAUAN CITY'},
        {'code': 'TAYSAN', 'name': 'TAYSAN'},
        {'code': 'TINGLOY', 'name': 'TINGLOY'},
        {'code': 'TUY', 'name': 'TUY'},
      ],
    };
    
    return provinceCities[provinceCode] ?? [];
  }

  // Get fallback barangays for offline use
  static List<Map<String, dynamic>> getFallbackBarangays(String cityCode) {
    // Return comprehensive barangay data for offline use
    final Map<String, List<Map<String, dynamic>>> cityBarangays = {
      'LAOAG CITY': [
        {'code': 'BRGY 1', 'name': 'BRGY 1'},
        {'code': 'BRGY 2', 'name': 'BRGY 2'},
        {'code': 'BRGY 3', 'name': 'BRGY 3'},
        {'code': 'BRGY 4', 'name': 'BRGY 4'},
        {'code': 'BRGY 5', 'name': 'BRGY 5'},
        {'code': 'BRGY 6', 'name': 'BRGY 6'},
        {'code': 'BRGY 7', 'name': 'BRGY 7'},
        {'code': 'BRGY 8', 'name': 'BRGY 8'},
        {'code': 'BRGY 9', 'name': 'BRGY 9'},
        {'code': 'BRGY 10', 'name': 'BRGY 10'},
      ],
      'BATANGAS CITY': [
        {'code': 'BRGY 1', 'name': 'BRGY 1'},
        {'code': 'BRGY 2', 'name': 'BRGY 2'},
        {'code': 'BRGY 3', 'name': 'BRGY 3'},
        {'code': 'BRGY 4', 'name': 'BRGY 4'},
        {'code': 'BRGY 5', 'name': 'BRGY 5'},
        {'code': 'BRGY 6', 'name': 'BRGY 6'},
        {'code': 'BRGY 7', 'name': 'BRGY 7'},
        {'code': 'BRGY 8', 'name': 'BRGY 8'},
        {'code': 'BRGY 9', 'name': 'BRGY 9'},
        {'code': 'BRGY 10', 'name': 'BRGY 10'},
      ],
    };
    
    return cityBarangays[cityCode] ?? [];
  }
}