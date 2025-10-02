# 📱 T.U.L.O.N.G APK Build Guide

## 🎯 Ensuring Firebase and SQLite Features in Your APK

This guide will help you build an APK that includes all Firebase and SQLite features.

## ✅ Pre-Build Checklist

### **1. Firebase Configuration**
- [ ] `android/app/google-services.json` exists
- [ ] Firebase project is properly configured
- [ ] All Firebase dependencies are in `pubspec.yaml`
- [ ] Firebase initialization is in `main.dart`

### **2. SQLite Configuration**
- [ ] `sqflite` dependency is in `pubspec.yaml`
- [ ] `path` dependency is in `pubspec.yaml`
- [ ] SQLite service is implemented
- [ ] Database operations are working

### **3. Android Configuration**
- [ ] `android/app/build.gradle.kts` has Google Services plugin
- [ ] `android/build.gradle.kts` has Google Services classpath
- [ ] `AndroidManifest.xml` has required permissions
- [ ] Package name matches Firebase configuration

## 🚀 Step-by-Step APK Build Process

### **Step 1: Verify Configuration**
```bash
# Run the verification script
flutter run lib/verify-apk-build.dart
```

### **Step 2: Clean and Prepare**
```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Check for any issues
flutter doctor
```

### **Step 3: Build APK**
```bash
# Windows
build-apk.bat

# Or manually
flutter build apk --release
```

### **Step 4: Test APK Features**
```bash
# Windows
test-apk-features.bat
```

## 🔍 Verification Steps

### **1. Firebase Integration Verification**

#### **Check Firebase Configuration**
```bash
# Verify google-services.json exists
ls android/app/google-services.json

# Check Firebase dependencies
flutter pub deps | grep firebase
```

#### **Test Firebase in APK**
```dart
// Add this to your app to test Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void testFirebase() async {
  await Firebase.initializeApp();
  final auth = FirebaseAuth.instance;
  print('Firebase initialized: ${auth != null}');
}
```

### **2. SQLite Integration Verification**

#### **Check SQLite Dependencies**
```bash
# Verify SQLite dependencies
flutter pub deps | grep sqflite
```

#### **Test SQLite in APK**
```dart
// Add this to your app to test SQLite
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void testSQLite() async {
  final database = await openDatabase(
    join(await getDatabasesPath(), 'test.db'),
    version: 1,
    onCreate: (db, version) async {
      await db.execute('CREATE TABLE test (id INTEGER PRIMARY KEY)');
    },
  );
  print('SQLite database created: ${database != null}');
}
```

## 📋 Required Dependencies for APK

### **Firebase Dependencies**
```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  firebase_database: ^10.4.0
  firebase_storage: ^11.5.6
  firebase_analytics: ^10.7.4
  firebase_messaging: ^14.7.10
```

### **SQLite Dependencies**
```yaml
dependencies:
  sqflite: ^2.3.0
  path: ^1.8.3
  connectivity_plus: ^5.0.2
  internet_connection_checker: ^1.0.0+1
  crypto: ^3.0.3
```

### **Android Permissions**
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## 🔧 Build Configuration

### **Android Build Configuration**
```kotlin
// android/app/build.gradle.kts
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Required for Firebase
}

android {
    defaultConfig {
        applicationId = "com.activity.tulong"
        minSdk = 21 // Required for SQLite
        targetSdk = 34
    }
}
```

### **Project Build Configuration**
```kotlin
// android/build.gradle.kts
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.0") // Required for Firebase
    }
}
```

## 🧪 Testing Your APK

### **1. Install APK**
```bash
# Install on connected device
adb install build/app/outputs/flutter-apk/app-release.apk

# Or install via file manager
```

### **2. Test Firebase Features**
- [ ] **Authentication** - Login/Register
- [ ] **Database** - Read/Write data
- [ ] **Storage** - Upload/Download files
- [ ] **Messaging** - Send/Receive messages
- [ ] **Analytics** - Track events

### **3. Test SQLite Features**
- [ ] **Database Creation** - Create tables
- [ ] **Data Operations** - Insert/Update/Delete
- [ ] **Offline Storage** - Store data locally
- [ ] **Data Sync** - Sync with Firebase

### **4. Test Offline Features**
- [ ] **Offline Mode** - Work without internet
- [ ] **Data Persistence** - Data survives app restart
- [ ] **Sync on Reconnect** - Sync when online
- [ ] **Emergency Alerts** - Send alerts offline

## 🚨 Troubleshooting

### **Common Issues & Solutions**

#### **1. Firebase Not Working**
```bash
# Check Firebase configuration
cat android/app/google-services.json

# Verify Firebase initialization
flutter run --verbose
```

#### **2. SQLite Not Working**
```bash
# Check SQLite dependencies
flutter pub deps | grep sqflite

# Test SQLite operations
flutter run lib/verify-apk-build.dart
```

#### **3. APK Too Large**
```bash
# Build with specific architectures
flutter build apk --target-platform android-arm64

# Or build app bundle instead
flutter build appbundle --release
```

#### **4. Permissions Issues**
```bash
# Check AndroidManifest.xml
cat android/app/src/main/AndroidManifest.xml

# Verify permissions in APK
aapt dump permissions build/app/outputs/flutter-apk/app-release.apk
```

### **Debug Commands**
```bash
# Check APK contents
aapt dump badging build/app/outputs/flutter-apk/app-release.apk

# Check APK permissions
aapt dump permissions build/app/outputs/flutter-apk/app-release.apk

# Check APK size
ls -la build/app/outputs/flutter-apk/app-release.apk
```

## 📊 APK Size Optimization

### **1. Remove Unused Dependencies**
```bash
# Analyze APK size
flutter build apk --analyze-size

# Remove unused dependencies
flutter pub deps
```

### **2. Optimize Images**
```bash
# Compress images
flutter packages pub run flutter_launcher_icons:main

# Use WebP format
flutter build apk --split-per-abi
```

### **3. Proguard Configuration**
```kotlin
// android/app/proguard-rules.pro
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
```

## 🎯 Success Criteria

Your APK is ready when:

- [ ] **APK builds successfully** without errors
- [ ] **Firebase features work** (auth, database, storage)
- [ ] **SQLite features work** (offline storage, sync)
- [ ] **Offline functionality works** (no internet required)
- [ ] **Emergency alerts work** (offline and online)
- [ ] **Messaging works** (real-time and offline)
- [ ] **File uploads work** (images, documents)
- [ ] **Analytics work** (user tracking, events)

## 📱 Final Testing Checklist

### **Before Release**
- [ ] Test on multiple devices
- [ ] Test with different Android versions
- [ ] Test offline functionality
- [ ] Test Firebase connection
- [ ] Test SQLite operations
- [ ] Test emergency alerts
- [ ] Test messaging features
- [ ] Test file uploads
- [ ] Test user authentication
- [ ] Test data synchronization

### **Performance Testing**
- [ ] App startup time
- [ ] Database query performance
- [ ] Firebase connection speed
- [ ] Offline sync performance
- [ ] Memory usage
- [ ] Battery usage

## 🆘 Support

If you encounter issues:

1. **Check build logs** for errors
2. **Verify Firebase Console** for configuration
3. **Test with debug APK** first
4. **Check device permissions**
5. **Review this guide** for solutions

---

**Remember**: Your APK will include both Firebase and SQLite features, providing a robust offline-first disaster communication system! 🚀
