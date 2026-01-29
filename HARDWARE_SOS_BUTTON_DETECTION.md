# Hardware SOS Button Detection & Pinning

## Overview
This document explains how SOS messages from the physical hardware button (ESP32) are detected, recognized, and automatically pinned in the app.

---

## ✅ Implementation Status

### **Hardware SOS Button Flow**

**ESP32 Hardware:**
- Physical SOS button on GPIO4 (INPUT_PULLUP)
- When pressed, ESP32 sends: `<MSG_START:UIDSOS>` + SOS message + `<MSG_END>`
- SOS message is read from ESP32 flash memory (cached)

**App Detection:**
- App receives the framed message via Bluetooth
- Detects `UIDSOS` in the message start marker
- Automatically marks message as emergency (`isEmergency = true`)
- Automatically pins the message (`isPinned = true`)

---

## 🔍 How It Works

### **1. Message Reception**

**Location:** `lib/providers/chat_provider.dart` (line 628-656)

When ESP32 sends a message:
```
<MSG_START:UIDSOS>
[SOS message content from flash]
<MSG_END>
```

The app:
1. Detects `<MSG_START:UIDSOS>` marker
2. Starts buffering the message
3. Stores `UIDSOS` as the sender UID
4. Continues buffering until `<MSG_END>` is received

---

### **2. SOS Detection**

**Location:** `lib/providers/chat_provider.dart` (line 879-881)

When the message is flushed:
```dart
// Check if this is an SOS message from hardware physical button
// ESP32 sends: <MSG_START:UIDSOS> + message + <MSG_END>
final isSosFromHardware = senderUid != null && 
                           (senderUid.toUpperCase().contains('SOS') || 
                            senderUid.toUpperCase().endsWith('SOS'));
```

**Detection Logic:**
- Checks if `senderUid` contains "SOS" (case-insensitive)
- Checks if `senderUid` ends with "SOS"
- If either condition is true → `isSosFromHardware = true`

---

### **3. Auto-Pinning**

**Location:** `lib/providers/chat_provider.dart` (line 945)

When the message is added:
```dart
// Display the complete message with emergency flag if from hardware SOS button
_addMessage(completeMessage, false, senderName: senderName ?? 'ESP', isEmergency: isSosFromHardware);
```

**What Happens:**
- `isEmergency: isSosFromHardware` → Sets emergency flag
- `isPinned: isEmergency` → Auto-pins the message (line 1169)
- `messageId` → Generated for tracking/unpinning

---

## 📊 Complete Flow

```
Physical SOS Button Pressed (ESP32)
    ↓
ESP32 reads SOS message from flash memory
    ↓
ESP32 sends: <MSG_START:UIDSOS> + message + <MSG_END>
    ↓
App receives via Bluetooth
    ↓
App detects UIDSOS in start marker
    ↓
App buffers message until <MSG_END>
    ↓
App detects "SOS" in senderUid
    ↓
isSosFromHardware = true
    ↓
_addMessage(..., isEmergency: true)
    ↓
Message auto-pinned (isPinned: true)
    ↓
Displayed in pinned section at top of chat
    ↓
Auto-unpinned after 1 hour
    ↓
Still in history (last 24 hours)
```

---

## ✅ Verification

### **Test Cases:**

1. **Hardware SOS Button Press:**
   - ✅ ESP32 sends `<MSG_START:UIDSOS>` format
   - ✅ App detects "SOS" in UID
   - ✅ Message marked as emergency
   - ✅ Message auto-pinned
   - ✅ Shows in pinned section

2. **Regular Message (Not SOS):**
   - ✅ ESP32 sends `<MSG_START:UID123>` format
   - ✅ App does NOT detect SOS
   - ✅ Message NOT marked as emergency
   - ✅ Message NOT pinned
   - ✅ Shows in regular chat

3. **Cached Memory SOS:**
   - ✅ ESP32 reads SOS from flash memory
   - ✅ Same detection logic applies
   - ✅ Works the same as real-time SOS

---

## 🔧 Code Locations

| Feature | File | Lines |
|---------|------|-------|
| Message buffering | `lib/providers/chat_provider.dart` | 628-656 |
| SOS detection | `lib/providers/chat_provider.dart` | 879-881 |
| Message flushing | `lib/providers/chat_provider.dart` | 862-945 |
| Auto-pinning | `lib/providers/chat_provider.dart` | 1169 |
| ESP32 SOS button | `esp32_node_A_nrf24.ino` | 784-803 |

---

## 📝 Notes

### **Current Status:**
- ✅ **Hardware SOS detection:** Implemented and working
- ✅ **Auto-pinning:** Works for hardware SOS messages
- ✅ **Cached memory:** Works the same as real-time SOS
- ⚠️ **Home page SOS button:** Still being worked on (separate feature)

### **Key Points:**
1. **Hardware SOS messages** are automatically detected via `UIDSOS` marker
2. **Auto-pinning** happens immediately when message is received
3. **Cached memory SOS** works the same way (reads from ESP32 flash)
4. **Home page SOS button** is a different feature (app-initiated, not hardware)

---

## 🎯 Summary

**Hardware SOS Button Detection: ✅ FULLY WORKING**

- Physical button press → ESP32 sends `<MSG_START:UIDSOS>` format
- App detects "SOS" in sender UID
- Message automatically marked as emergency
- Message automatically pinned
- Shows in pinned section at top of chat
- Auto-unpinned after 1 hour
- Available in history (last 24 hours)

**The implementation is complete and working!**
