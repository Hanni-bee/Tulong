# 🏗️ T.U.L.O.N.G App Architecture - ESP32 Hardware Integration

**Document Version:** 1.0  
**Last Updated:** December 2024  
**Purpose:** Comprehensive guide on how the app works with ESP32 hardware

---

## 📋 Overview

T.U.L.O.N.G is an **emergency communication app** that relies heavily on **ESP32 hardware** for offline mesh networking. This document explains the architecture, data flow, and how software integrates with hardware.

---

## 🔌 ESP32 Hardware Dependency

### **Critical Hardware Requirements**

1. **ESP32 Devices**
   - Required for all communication features
   - Handles Bluetooth connectivity
   - Manages LoRa/Radio transmission
   - Stores and forwards messages

2. **Bluetooth Communication**
   - App connects to ESP32 via Bluetooth
   - ESP32 handles device-to-device communication
   - Messages are transmitted through ESP32 mesh network

3. **Hardware Limitations**
   - **Text-only messages** - ESP32 transmits text, not rich media
   - **Limited bandwidth** - Messages must be concise
   - **Connection-dependent** - Features require ESP32 connection
   - **Battery-powered** - ESP32 devices run on battery

---

## 🏛️ Architecture Overview

### **System Components**

```
┌─────────────────────────────────────────────────────────┐
│                    FLUTTER APP                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   UI Layer   │  │  State Mgmt  │  │   Services   │  │
│  │  (Screens)   │  │  (Provider)  │  │ (Bluetooth)  │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                  │                  │          │
│         └──────────────────┼──────────────────┘          │
│                            │                             │
│                    ┌───────▼────────┐                    │
│                    │ Bluetooth API  │                    │
│                    └───────┬────────┘                    │
└────────────────────────────┼────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │   ESP32 DEVICE  │
                    │                 │
                    │  ┌───────────┐ │
                    │  │ Bluetooth │ │
                    │  │  Stack    │ │
                    │  └─────┬─────┘ │
                    │        │       │
                    │  ┌─────▼─────┐ │
                    │  │ LoRa/Radio│ │
                    │  │  Module   │ │
                    │  └───────────┘ │
                    └────────────────┘
                             │
                    ┌────────▼────────┐
                    │  MESH NETWORK   │
                    │  (Other ESP32s) │
                    └─────────────────┘
```

---

## 📡 Communication Flow

### **Message Sending Flow**

1. **User Types Message** (Flutter App)
   ```
   User → TextField → MessageController
   ```

2. **Message Processing** (Flutter App)
   ```
   MessageController → ChatProvider.sendMessage()
   → Format message (text-only)
   → Add metadata (timestamp, sender, emergency flag)
   ```

3. **Bluetooth Transmission** (Flutter → ESP32)
   ```
   ChatProvider → BluetoothService
   → Send via Bluetooth Serial
   → ESP32 receives message
   ```

4. **ESP32 Processing** (ESP32 Hardware)
   ```
   ESP32 receives message
   → Stores in flash memory
   → Broadcasts via LoRa/Radio
   → Forwards to connected devices
   ```

5. **Message Delivery** (ESP32 → Other Devices)
   ```
   ESP32 mesh network
   → Other ESP32 devices receive
   → Forward to connected Flutter apps
   ```

### **Message Receiving Flow**

1. **ESP32 Receives** (Hardware)
   ```
   ESP32 receives via LoRa/Radio
   → Stores in flash memory
   → Forwards via Bluetooth
   ```

2. **Bluetooth Reception** (ESP32 → Flutter)
   ```
   ESP32 → Bluetooth Serial
   → BluetoothService.messageStream
   → ChatProvider receives
   ```

3. **Message Processing** (Flutter App)
   ```
   ChatProvider._processIncomingMessage()
   → Parse message format
   → Extract sender, text, metadata
   → Create ChatMessage object
   ```

4. **UI Update** (Flutter App)
   ```
   ChatProvider._addMessage()
   → Add to _messages list
   → notifyListeners()
   → UI updates via Consumer<ChatProvider>
   ```

---

## 🔄 Data Flow Details

### **Connection Flow**

1. **App Startup**
   - App initializes `BluetoothService`
   - Scans for paired ESP32 devices
   - Attempts to connect to last connected device

2. **ESP32 Connection**
   - User selects ESP32 device
   - App connects via Bluetooth
   - ESP32 authenticates connection
   - Connection status updates in UI

3. **Message Exchange**
   - App sends messages to ESP32
   - ESP32 broadcasts to mesh network
   - Other ESP32s receive and forward
   - Connected apps receive messages

4. **Disconnection Handling**
   - App detects disconnection
   - Queues messages for retry
   - Attempts auto-reconnect
   - Shows connection status in UI

---

## 💾 Data Storage

### **Local Storage (Flutter App)**

1. **SQLite Database**
   - Messages (sent and received)
   - User profile data
   - Settings and preferences
   - Contact information

2. **SharedPreferences**
   - Session data (user UID)
   - Last connected device
   - App settings
   - Authentication tokens

3. **File Storage**
   - Voice message recordings
   - Emergency detection images
   - Exported data

### **ESP32 Flash Storage**

1. **Message Buffer**
   - Stores messages temporarily
   - Forwards when devices connect
   - Clears after delivery

2. **Device Configuration**
   - Network settings
   - Device ID
   - Connection parameters

---

## 🔐 Authentication & Security

### **ESP32 Authentication**

1. **Pairing Process**
   - User pairs ESP32 via Bluetooth settings
   - ESP32 stores paired device info
   - App authenticates on connection

2. **Message Authentication**
   - Messages include sender UID
   - ESP32 validates sender
   - Prevents unauthorized messages

3. **Privacy**
   - Messages encrypted locally (optional)
   - User data stored securely
   - No cloud storage (100% offline)

---

## 📱 App Features & ESP32 Integration

### **1. Local Chat**
**How it works:**
- User types message → App sends to ESP32 via Bluetooth
- ESP32 broadcasts to mesh network
- Other ESP32s receive and forward to connected apps
- Messages appear in chat in real-time

**ESP32 Requirements:**
- Bluetooth connectivity
- LoRa/Radio module for mesh networking
- Flash memory for message buffering

---

### **2. Emergency Messages**
**How it works:**
- User sends emergency message → App marks as emergency
- ESP32 prioritizes emergency messages
- Emergency messages broadcast immediately
- All connected devices receive emergency alerts

**ESP32 Requirements:**
- Priority message handling
- Fast broadcast capability
- Emergency message flag support

---

### **3. Voice Messages**
**How it works:**
- User records voice → App converts to Base64
- App sends Base64 string to ESP32
- ESP32 transmits as text (Base64)
- Receiving app decodes and plays audio

**ESP32 Requirements:**
- Text transmission support (Base64)
- Larger message size handling
- Message chunking for long audio

---

### **4. Emergency Detection**
**How it works:**
- User captures photo → App analyzes locally
- App classifies emergency type
- App sends text description to ESP32
- ESP32 broadcasts emergency alert

**ESP32 Requirements:**
- Text message transmission
- Emergency flag support
- Priority message handling

---

## ⚙️ Hardware Constraints & Considerations

### **ESP32 Limitations**

1. **Text-Only Messages**
   - ESP32 transmits text, not binary data
   - Images must be described in text
   - Voice must be Base64 encoded
   - Rich media not supported

2. **Message Size Limits**
   - ESP32 has message size limits
   - Long messages must be chunked
   - Voice messages split into chunks
   - App handles chunking/reassembly

3. **Connection Dependency**
   - Features require ESP32 connection
   - Offline mode queues messages
   - Auto-reconnect when ESP32 available
   - Clear connection status in UI

4. **Battery Considerations**
   - ESP32 devices are battery-powered
   - App should minimize Bluetooth usage
   - Power-saving mode for extended use
   - Battery level monitoring

5. **Network Range**
   - ESP32 mesh network has range limits
   - Messages only reach nearby devices
   - Range depends on LoRa/Radio module
   - UI should indicate network range

---

## 🛠️ Implementation Guidelines

### **For Developers**

1. **Always Check ESP32 Connection**
   ```dart
   if (!bluetoothService.isConnected) {
     // Show connection required message
     // Queue message for later
   }
   ```

2. **Handle Hardware Errors**
   ```dart
   try {
     await bluetoothService.sendMessage(text);
   } catch (e) {
     // Handle ESP32 connection error
     // Show user-friendly error
     // Queue message for retry
   }
   ```

3. **Respect Hardware Limitations**
   - Keep messages concise (text-only)
   - Chunk large messages
   - Handle connection failures gracefully
   - Show clear connection status

4. **Optimize for Battery**
   - Minimize Bluetooth operations
   - Batch messages when possible
   - Implement power-saving mode
   - Monitor battery level

---

## 🎨 UI/UX Considerations

### **Hardware Status Indicators**

1. **Connection Status**
   - Show ESP32 connection status clearly
   - Display connection quality (Strong/Weak)
   - Show last message time
   - Indicate connection retry status

2. **Hardware Requirements**
   - Show when ESP32 is required
   - Guide users to connect ESP32
   - Display paired devices list
   - Help users pair new devices

3. **Error Handling**
   - Clear messages for hardware errors
   - Actionable suggestions ("Check ESP32 power")
   - Retry options for failed operations
   - Queue status for offline messages

---

## 📊 Feature Compatibility Matrix

| Feature | ESP32 Required | Works Offline | Text-Only |
|---------|---------------|--------------|-----------|
| Local Chat | ✅ Yes | ✅ Yes | ✅ Yes |
| Emergency Messages | ✅ Yes | ✅ Yes | ✅ Yes |
| Voice Messages | ✅ Yes | ✅ Yes | ✅ Base64 |
| Emergency Detection | ✅ Yes | ✅ Yes | ✅ Text desc |
| Contact Management | ❌ No | ✅ Yes | N/A |
| Message History | ❌ No | ✅ Yes | N/A |
| Settings | ❌ No | ✅ Yes | N/A |

---

## 🔄 Message Format

### **Standard Message Format**

```json
{
  "type": "message",
  "text": "Message content here",
  "sender": "User Name",
  "senderUID": "user_uid_123",
  "timestamp": 1234567890,
  "isEmergency": false,
  "messageId": "msg_123"
}
```

### **Emergency Message Format**

```json
{
  "type": "emergency",
  "text": "🚨 EMERGENCY: Need help!",
  "sender": "User Name",
  "senderUID": "user_uid_123",
  "timestamp": 1234567890,
  "isEmergency": true,
  "emergencyType": "medical",
  "location": "14.5995°N, 120.9842°E",
  "messageId": "emergency_123"
}
```

### **Voice Message Format**

```
VOICE_MESSAGE:<base64_encoded_audio_data>
```

---

## 🚨 Error Handling

### **Common ESP32 Errors**

1. **Connection Failed**
   - **Cause:** ESP32 not powered, out of range, not paired
   - **UI:** Show "ESP32 not connected" message
   - **Action:** Guide user to connect ESP32
   - **Queue:** Queue messages for retry

2. **Message Send Failed**
   - **Cause:** ESP32 disconnected, message too large, network error
   - **UI:** Show "Message failed to send" with retry button
   - **Action:** Retry sending, queue for later
   - **Queue:** Add to message queue

3. **ESP32 Not Found**
   - **Cause:** ESP32 not powered, Bluetooth off, not paired
   - **UI:** Show "No ESP32 devices found"
   - **Action:** Guide user to pair ESP32
   - **Queue:** Queue messages until connected

---

## 📝 Development Notes

### **Testing Requirements**

1. **Hardware Testing**
   - Test with actual ESP32 devices
   - Test connection/disconnection scenarios
   - Test message transmission
   - Test emergency message priority

2. **Offline Testing**
   - Test message queuing
   - Test auto-reconnect
   - Test message delivery after reconnect
   - Test battery-saving mode

3. **Error Testing**
   - Test connection failures
   - Test message send failures
   - Test ESP32 not found
   - Test network range limits

---

## 🎯 Key Takeaways

1. **ESP32 is Required** - App cannot function fully without ESP32 hardware
2. **Text-Only Communication** - All messages must be text or Base64-encoded
3. **Connection-Dependent** - Features require ESP32 connection
4. **Offline Queue** - Messages queue when ESP32 disconnected
5. **Hardware Status** - UI must clearly show ESP32 connection status
6. **Battery Awareness** - App must optimize for battery-powered devices
7. **Error Handling** - Graceful handling of hardware failures

---

## 📚 Related Documentation

- `SENIOR_QA_UI_UX_REVIEW.md` - UI/UX improvements (ESP32-aware)
- `UI_UX_IMPROVEMENTS_PORT_SUMMARY.md` - UI porting summary
- ESP32 Hardware Documentation (external)

---

**End of Architecture Document**

*This document explains how the app integrates with ESP32 hardware. All features and improvements must be compatible with ESP32 constraints.*
