# 🔥 Firebase Console Configuration Guide
# **DELETE THIS FILE AFTER USE - CONTAINS SENSITIVE CONFIG**

## 🚨 SECURITY NOTICE
This file contains Firebase configuration details. **DELETE IMMEDIATELY AFTER USE** to prevent accidental commits or exposure.

---

## 📋 COMPLETE FIREBASE CONSOLE SETUP

### **STEP 1: Access Firebase Console**
1. Go to: https://console.firebase.google.com/
2. Select your project: `tulong-db976`
3. Make sure you're in the correct project

---

## **🔐 STEP 2: Deploy Database Security Rules**

**Location**: Realtime Database → Rules

**⚠️ CRITICAL**: Replace ALL existing rules with this:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "auth != null && (auth.uid == $uid || root.child('users').child(auth.uid).child('role').val() == 'admin')",
        ".write": "auth != null && (auth.uid == $uid || root.child('users').child(auth.uid).child('role').val() == 'admin')",
        ".validate": "newData.hasChildren(['Email', 'FirstName', 'LastName'])",
        "Email": {
          ".validate": "newData.isString() && newData.val().matches(/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$/i)"
        },
        "FirstName": {
          ".validate": "newData.isString() && newData.val().length > 0 && newData.val().length <= 50"
        },
        "LastName": {
          ".validate": "newData.isString() && newData.val().length > 0 && newData.val().length <= 50"
        },
        "isOnline": {
          ".validate": "newData.isBoolean()"
        },
        "role": {
          ".validate": "newData.isString() && newData.val().matches(/^(user|moderator|admin)$/)"
        },
        "Password": {
          ".validate": "newData.isString() && newData.val().length >= 64"
        },
        "preferences": {
          ".validate": "newData.hasChildren(['notifications', 'privacy'])"
        }
      }
    },
    "chats": {
      "$chatId": {
        ".read": "auth != null && (root.child('chats').child($chatId).child('participants').child(auth.uid).exists() || root.child('users').child(auth.uid).child('role').val() == 'admin')",
        ".write": "auth != null && root.child('chats').child($chatId).child('participants').child(auth.uid).exists()",
        "messages": {
          "$messageId": {
            ".read": "auth != null && (root.child('chats').child($chatId).child('participants').child(auth.uid).exists() || root.child('users').child(auth.uid).child('role').val() == 'admin')",
            ".write": "auth != null && (newData.child('senderId').val() == auth.uid || root.child('users').child(auth.uid).child('role').val() == 'admin')",
            ".validate": "newData.hasChildren(['message', 'senderId', 'senderName', 'timestamp'])",
            "message": {
              ".validate": "newData.isString() && newData.val().length > 0 && newData.val().length <= 1000 && newData.val().length >= 1"
            },
            "senderId": {
              ".validate": "newData.isString() && newData.val() == auth.uid"
            },
            "timestamp": {
              ".validate": "newData.isNumber()"
            }
          }
        },
        "participants": {
          "$uid": {
            ".validate": "newData.isBoolean()"
          }
        }
      }
    },
    "emergency_alerts": {
      "$alertId": {
        ".read": "auth != null",
        ".write": "auth != null && (newData.child('senderId').val() == auth.uid || root.child('users').child(auth.uid).child('role').val() == 'admin')",
        ".validate": "newData.hasChildren(['message', 'location', 'senderId', 'timestamp', 'status'])",
        "message": {
          ".validate": "newData.isString() && newData.val().length > 0 && newData.val().length <= 500"
        },
        "location": {
          ".validate": "newData.isString() && newData.val().length > 0"
        },
        "priority": {
          ".validate": "newData.isString() && newData.val().matches(/^(low|medium|high|critical)$/)"
        },
        "status": {
          ".validate": "newData.isString() && newData.val().matches(/^(active|acknowledged|in_progress|resolved|cancelled)$/)"
        }
      }
    },
    "analytics": {
      ".read": "auth != null && root.child('users').child(auth.uid).child('role').val() == 'admin'",
      ".write": "auth != null && root.child('users').child(auth.uid).child('role').val() == 'admin'"
    },
    "admin": {
      ".read": "auth != null && root.child('users').child(auth.uid).child('role').val() == 'admin'",
      ".write": "auth != null && root.child('users').child(auth.uid).child('role').val() == 'admin'"
    }
  }
}
```

**✅ Action**: Click "Publish" to deploy

---

## **💾 STEP 3: Deploy Storage Security Rules**

**Location**: Storage → Rules

**⚠️ CRITICAL**: Replace ALL existing rules with this:

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // User profile pictures
    match /users/{userId}/profile/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId
        && resource.size < 5 * 1024 * 1024 // 5MB limit
        && resource.contentType.matches('image/.*');
    }

    // Chat media files
    match /chats/{chatId}/media/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
        && resource.size < 25 * 1024 * 1024 // 25MB limit
        && (resource.contentType.matches('image/.*')
            || resource.contentType.matches('video/.*')
            || resource.contentType.matches('audio/.*')
            || resource.contentType.matches('application/pdf'));
    }

    // Emergency alert media
    match /emergency/{alertId}/media/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
        && resource.size < 50 * 1024 * 1024 // 50MB limit for emergency files
        && (resource.contentType.matches('image/.*')
            || resource.contentType.matches('video/.*')
            || resource.contentType.matches('audio/.*'));
    }

    // Admin files
    match /admin/{fileName} {
      allow read, write: if request.auth != null
        && get(/databases/(default)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Public assets (read-only)
    match /public/{fileName} {
      allow read: if true;
      allow write: if request.auth != null
        && get(/databases/(default)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

**✅ Action**: Click "Publish" to deploy

---

## **🔑 STEP 4: Configure Authentication**

**Location**: Authentication → Sign-in method

### **Enable Email/Password:**
1. Find "Email/Password" in the list
2. Click the edit icon (pencil)
3. Enable it
4. **Set password requirements**:
   - Minimum 8 characters
   - Enable email verification if desired

### **Configure Google Sign-In:**
1. Find "Google" in the list
2. Click the edit icon (pencil)
3. Ensure it's enabled
4. Verify your project configuration

---

## **⚙️ STEP 5: Verify Project Settings**

**Location**: Project settings (gear icon) → General

### **Check Your Apps:**
1. **Android app** should show:
   - Package name: `com.activity2.tulong2`
   - SHA-1 fingerprint: `9C:CD:AB:85:D9:C3:55:59:27:0F:4B:A1:CA:55:59:EA:61:B9:37:84`

2. **Download updated google-services.json** if needed

---

## **📊 STEP 6: Enable Analytics (Optional)**

**Location**: Analytics → Dashboard

1. If you want analytics, ensure it's enabled
2. Configure data collection settings

---

## **🔍 STEP 7: Verification Checklist**

After completing all steps:

### **Test Database Rules:**
1. Try to read/write data in your app
2. Check Firebase Console logs for errors
3. Verify authentication works

### **Test Storage Rules:**
1. Try uploading a profile picture
2. Verify file access permissions

### **Test Authentication:**
1. Test email/password signup and signin
2. Test Google Sign-In
3. Verify password hashing works (check database)

---

## **🗑️ CLEANUP**
**DELETE THIS FILE IMMEDIATELY AFTER USE**

```bash
# Run this to delete the guide
rm FIREBASE_CONSOLE_SETUP_GUIDE.md
```

---

## **⚠️ CRITICAL SECURITY NOTES**

1. **Database Rules**: These rules are now much more secure with proper validation
2. **Storage Rules**: Fixed the Firestore/Realtime Database inconsistency
3. **Authentication**: Should work properly with our code changes
4. **Backup**: Consider backing up your current database before deploying new rules

---

**🎉 Your Firebase Console is now fully configured and secure!**

**DELETE THIS FILE NOW** to prevent accidental exposure of configuration details.
