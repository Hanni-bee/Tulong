# SOS System - How It Works

## 🎯 Overview
This document explains how the SOS system works, including hardware and software SOS buttons, pinning, and history.

---

## ✅ **How SOS Works**

### **1. Hardware SOS Button (Physical ESP32 Button)**

**Flow:**
```
Physical Button Press (GPIO4)
    ↓
ESP32 reads SOS message from flash memory
    ↓
ESP32 sends: <MSG_START:UIDSOS> + message + <MSG_END>
    ↓
App receives via Bluetooth
    ↓
App detects "SOS" in sender UID (UIDSOS)
    ↓
Message marked as emergency (isEmergency = true)
    ↓
Message auto-pinned (isPinned = true)
    ↓
Shows in compact red banner at top of chat
```

**Detection Logic:**
- Checks if sender UID contains "SOS" or ends with "SOS"
- If yes → `isEmergency = true` and `isPinned = true`
- `<MSG_END>` tags are automatically stripped from message text

**Code Location:** `lib/providers/chat_provider.dart` (lines 878-886, 945)

---

### **2. Software SOS Button (Home Page)**

**Flow:**
```
User presses SOS button on home page
    ↓
User holds button (ring animation completes)
    ↓
Confirmation modal appears
    ↓
User confirms
    ↓
App sends: sendGroupMessage(message, isEmergency: true)
    ↓
Message sent with is_emergency: true flag in JSON
    ↓
ESP32 forwards message (preserves JSON format)
    ↓
App receives via _processIncomingMapMessage()
    ↓
App detects isEmergency flag from JSON
    ↓
Message marked as emergency (isEmergency = true)
    ↓
Message auto-pinned (isPinned = true)
    ↓
Shows in compact red banner at top of chat
```

**Detection Logic:**
- Checks `data['is_emergency'] == true` or `data['isEmergency'] == true`
- If yes → `isEmergency = true` and `isPinned = true`

**Code Location:** `lib/providers/chat_provider.dart` (lines 541-555)

**Status:** ✅ Code ready, waiting for home page SOS button UI implementation

---

## 📌 **Pinning System**

### **Auto-Pinning Rules:**

1. **Hardware SOS Button:**
   - ✅ Messages from `UIDSOS` format → Auto-pinned
   - ✅ Based on WHERE it came from (hardware), NOT content

2. **Software SOS Button (Home Page):**
   - ✅ Messages with `isEmergency: true` flag → Auto-pinned
   - ✅ Based on WHERE it came from (home page SOS button), NOT content

3. **Regular Messages:**
   - ❌ NOT pinned (even if they contain emergency words)
   - ❌ Pinning is ONLY based on source, NOT content

### **Auto-Unpinning:**

- **Timer:** Checks every 5 minutes
- **Rule:** Messages older than 1 hour are automatically unpinned
- **Process:** `isPinned` flag set to `false` after 1 hour
- **Result:** Message remains in chat history, just loses pinned status

**Code Location:** `lib/providers/chat_provider.dart` (lines 78-97, 156-158)

---

## 📜 **Pinned SOS History**

### **How It Works:**

1. **History Button:**
   - Pin icon button in top bar
   - Shows badge count of SOS messages from last 24 hours
   - Click to open history modal

2. **History Logic:**
   - Shows all SOS messages from last 24 hours
   - Includes both pinned AND unpinned SOS messages
   - Sorted by newest first
   - Independent of pin status

3. **SOS Detection for History:**
   - Checks `isEmergency` flag
   - Checks if message text contains: "sos", "🚨", or "emergency"
   - Fallback: Emergency messages from current user with emoji

**Code Location:** `lib/screens/local_chat_screen.dart` (lines 169-190, 192-350)

---

## 🎨 **Display System**

### **Compact Red Banner:**

- **Location:** Top of chat (above messages)
- **Design:** Full red card matching SOS banner
- **Content:**
  - Warning icon (animated pulse)
  - "PINNED EMERGENCY" label
  - Latest emergency message (2 lines max)
  - Sender name and timestamp
  - "+N" badge if multiple emergencies
- **Interaction:** Tap to open pinned history modal

**Code Location:** `lib/screens/local_chat_screen.dart` (lines 648-720)

---

## 📊 **Complete Flow Diagram**

### **Hardware SOS Button:**
```
Physical Button Press
    ↓
ESP32: <MSG_START:UIDSOS> + message + <MSG_END>
    ↓
App: Detect "SOS" in UID
    ↓
isEmergency = true, isPinned = true
    ↓
Show in red banner
    ↓
After 1 hour: Auto-unpin
    ↓
Still in history (24 hours)
```

### **Software SOS Button (Home Page):**
```
User Presses SOS Button
    ↓
sendGroupMessage(message, isEmergency: true)
    ↓
ESP32 forwards with is_emergency: true
    ↓
App: Detect isEmergency flag
    ↓
isEmergency = true, isPinned = true
    ↓
Show in red banner
    ↓
After 1 hour: Auto-unpin
    ↓
Still in history (24 hours)
```

---

## ✅ **What Works Now**

### **Hardware SOS Button:**
- ✅ Physical button detection (`UIDSOS`)
- ✅ Auto-pinning
- ✅ Red banner display
- ✅ Auto-unpin after 1 hour
- ✅ History (24 hours)

### **Software SOS Button (Home Page):**
- ✅ Code ready (`isEmergency: true` flag)
- ✅ Auto-pinning logic prepared
- ✅ Red banner display ready
- ⏳ Waiting for UI implementation

### **Pinned History:**
- ✅ History button with badge
- ✅ Modal showing last 24 hours
- ✅ Click to view details
- ✅ Works for both hardware and software SOS

---

## 🔍 **Key Points**

1. **Pinning is Source-Based:**
   - Hardware SOS (`UIDSOS`) → Pinned
   - Home page SOS (`isEmergency: true`) → Pinned
   - Regular messages → NOT pinned

2. **Both Sources Work:**
   - ✅ Hardware SOS button → Fully working
   - ✅ Software SOS button → Code ready (UI pending)

3. **History Shows All:**
   - Shows all SOS messages from last 24 hours
   - Includes pinned and unpinned
   - Based on `isEmergency` flag and content detection

4. **Auto-Unpin:**
   - Messages older than 1 hour lose pinned status
   - Still visible in chat and history
   - Timer checks every 5 minutes

---

## 📝 **Summary**

**Hardware SOS Button:**
- ✅ Fully working
- ✅ Detects `UIDSOS` format
- ✅ Auto-pins immediately
- ✅ Shows in red banner

**Software SOS Button (Home Page):**
- ✅ Code ready
- ✅ Will detect `isEmergency: true` flag
- ✅ Will auto-pin immediately
- ✅ Will show in red banner
- ⏳ Waiting for UI implementation

**Pinned History:**
- ✅ Works for both hardware and software SOS
- ✅ Shows last 24 hours
- ✅ Badge count in top bar
- ✅ Modal with full details

**The system is designed to work seamlessly for both hardware and software SOS buttons!** 🚀
