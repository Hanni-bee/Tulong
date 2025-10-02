import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // User Data
  Future<void> saveUser(Map<String, dynamic> user) async {
    await _prefs?.setString('user_data', jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUser() async {
    final userData = _prefs?.getString('user_data');
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }

  Future<void> clearUser() async {
    await _prefs?.remove('user_data');
  }

  // Messages
  Future<void> saveMessages(String chatId, List<Map<String, dynamic>> messages) async {
    await _prefs?.setString('messages_$chatId', jsonEncode(messages));
  }

  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final messagesData = _prefs?.getString('messages_$chatId');
    if (messagesData != null) {
      final List<dynamic> messages = jsonDecode(messagesData);
      return messages.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> clearMessages(String chatId) async {
    await _prefs?.remove('messages_$chatId');
  }

  // Settings
  Future<void> saveSetting(String key, dynamic value) async {
    if (value is String) {
      await _prefs?.setString(key, value);
    } else if (value is int) {
      await _prefs?.setInt(key, value);
    } else if (value is double) {
      await _prefs?.setDouble(key, value);
    } else if (value is bool) {
      await _prefs?.setBool(key, value);
    } else if (value is List<String>) {
      await _prefs?.setStringList(key, value);
    }
  }

  Future<T?> getSetting<T>(String key) async {
    return _prefs?.get(key) as T?;
  }

  // Emergency Contacts
  Future<void> saveEmergencyContacts(List<Map<String, dynamic>> contacts) async {
    await _prefs?.setString('emergency_contacts', jsonEncode(contacts));
  }

  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final contactsData = _prefs?.getString('emergency_contacts');
    if (contactsData != null) {
      final List<dynamic> contacts = jsonDecode(contactsData);
      return contacts.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // App Preferences
  Future<void> setDarkMode(bool isDark) async {
    await _prefs?.setBool('dark_mode', isDark);
  }

  Future<bool> isDarkMode() async {
    return _prefs?.getBool('dark_mode') ?? false;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs?.setBool('notifications_enabled', enabled);
  }

  Future<bool> areNotificationsEnabled() async {
    return _prefs?.getBool('notifications_enabled') ?? true;
  }

  Future<void> setAutoConnect(bool enabled) async {
    await _prefs?.setBool('auto_connect', enabled);
  }

  Future<bool> isAutoConnectEnabled() async {
    return _prefs?.getBool('auto_connect') ?? true;
  }

  // Clear all data
  Future<void> clearAll() async {
    await _prefs?.clear();
  }

  // Get storage size
  Future<int> getStorageSize() async {
    final keys = _prefs?.getKeys() ?? {};
    int totalSize = 0;
    
    for (String key in keys) {
      final value = _prefs?.get(key);
      if (value is String) {
        totalSize += value.length;
      }
    }
    
    return totalSize;
  }
}
