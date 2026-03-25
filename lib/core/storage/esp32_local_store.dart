import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight persistence for RF chat backup (best-effort).
class Esp32LocalStore {
  static const _kMessagesKey = 'esp32_rf_chat_messages_json';
  static const _kLastDeviceAddr = 'esp32_last_bt_address';
  static const _kLastDeviceName = 'esp32_last_bt_name';

  static Future<void> saveLastDevice({required String address, String? name}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLastDeviceAddr, address);
    if (name != null) await p.setString(_kLastDeviceName, name);
  }

  static Future<void> clearLastDevice() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kLastDeviceAddr);
    await p.remove(_kLastDeviceName);
  }

  static Future<String?> getLastDeviceAddress() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kLastDeviceAddr);
  }

  static Future<void> saveMessagesJson(String json) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kMessagesKey, json);
  }

  static Future<String?> loadMessagesJson() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kMessagesKey);
  }
}
