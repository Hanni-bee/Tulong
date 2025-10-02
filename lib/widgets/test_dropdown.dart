import 'package:flutter/material.dart';
import '../services/location_service.dart';

class TestDropdown extends StatefulWidget {
  const TestDropdown({super.key});

  @override
  State<TestDropdown> createState() => _TestDropdownState();
}

class _TestDropdownState extends State<TestDropdown> {
  List<Map<String, dynamic>> _regions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
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
    } catch (e) {
      setState(() {
        _regions = LocationService.getFallbackRegions();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Dropdown')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Testing Location API'),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              DropdownButton<String>(
                items: _regions.map((region) {
                  return DropdownMenuItem<String>(
                    value: region['code'],
                    child: Text(region['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  print('Selected: $value');
                },
                hint: const Text('Select Region'),
              ),
            const SizedBox(height: 20),
            Text('Loaded ${_regions.length} regions'),
          ],
        ),
      ),
    );
  }
}
