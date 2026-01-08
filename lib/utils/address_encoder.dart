import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/user_model.dart';
import '../services/philippine_location_service.dart';

class AddressEncodingResult {
  final String fullAddress;
  final String encodedAddress;
  final String regionKey;

  const AddressEncodingResult({
    required this.fullAddress,
    required this.encodedAddress,
    required this.regionKey,
  });
}

/// Produces a human-friendly full address AND a compact encoded address.
///
/// Goal: short + stable for BLE/mesh payloads, while keeping full address readable in the SOS text.
class AddressEncoder {
  static AddressEncodingResult fromUser(UserModel? user) {
    final street = (user?.street ?? '').trim();
    final barangay = (user?.barangay ?? '').trim();
    final city = (user?.city ?? '').trim();
    final province = (user?.province ?? '').trim();
    final region = (user?.region ?? '').trim();

    final parts = <String>[
      if (street.isNotEmpty) street,
      if (barangay.isNotEmpty) barangay,
      if (city.isNotEmpty) city,
      if (province.isNotEmpty) province,
      if (region.isNotEmpty) region,
    ];

    final full = parts.join(', ');
    if (full.isEmpty) {
      return const AddressEncodingResult(fullAddress: '', encodedAddress: '', regionKey: '');
    }

    final rk = PhilippineLocationService.instance.getRegionKey(region);
    final hash = sha1.convert(utf8.encode(full)).toString().substring(0, 6).toUpperCase();

    String shortPart(String s) {
      final normalized = s
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (normalized.isEmpty) return 'XXX';
      return (normalized.length >= 3 ? normalized.substring(0, 3) : normalized.padRight(3, 'X'));
    }

    final regionToken = rk.isNotEmpty ? rk.toUpperCase() : shortPart(region);
    final encoded = 'R$regionToken-${shortPart(province)}-${shortPart(city)}-${shortPart(barangay)}-$hash';

    return AddressEncodingResult(
      fullAddress: full,
      encodedAddress: encoded,
      regionKey: rk,
    );
  }
}


