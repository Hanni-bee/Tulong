# TULONG Hardware Integration Architecture

## 📡 Hardware Setup (ESP32 + SX1278)

### **Hardware Role: Pure RF Transceiver**
The hardware acts as a **passive radio modem** controlled entirely by the mobile app:

```
┌─────────────────────────────────────────────┐
│         MOBILE PHONE (ANDROID)              │
│  ┌──────────────────────────────────────┐   │
│  │      TULONG APP (Flutter)            │   │
│  │  • All UI controls                   │   │
│  │  • PTT button                        │   │
│  │  • Message sending                   │   │
│  │  • User interactions                 │   │
│  │  • Audio processing                  │   │
│  └──────────────┬───────────────────────┘   │
│                 │ USB OTG                    │
│                 ▼                            │
│  ┌──────────────────────────────────────┐   │
│  │   ESP32 WROOM 32 + SX1278 LoRa       │   │
│  │  • RF signal reception               │   │
│  │  • RF signal transmission            │   │
│  │  • 433MHz LoRa communication         │   │
│  │  • Serial command interface          │   │
│  │  • Power bank functionality          │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

---

## 🎯 Hardware Capabilities

### **What the Hardware DOES:**
✅ **Receive RF signals** (433MHz LoRa)
✅ **Transmit RF signals** (433MHz LoRa)
✅ **Convert digital data to RF**
✅ **Convert RF to digital data**
✅ **Act as power bank** for phone
✅ **Accept serial commands** from phone via USB OTG

### **What the Hardware DOES NOT DO:**
❌ No buttons or physical controls
❌ No display or UI
❌ No audio processing
❌ No user interaction
❌ No standalone operation

---

## 📱 Mobile App Control

### **All Controls Are in the App:**

#### **1. Push-to-Talk (PTT)**
```dart
// User presses button in app
HardwareService().startVoiceTransmission();
  ↓
// App captures audio from phone microphone
  ↓
// App sends audio data to ESP32 via USB OTG
  ↓
// ESP32 transmits via SX1278 LoRa (433MHz)
```

#### **2. Message Sending**
```dart
// User types message in app
HardwareService().sendLoRaMessage("Hello!");
  ↓
// App converts message to data packet
  ↓
// App sends packet to ESP32 via USB OTG
  ↓
// ESP32 transmits via SX1278 LoRa (433MHz)
```

#### **3. Receiving Messages**
```dart
// SX1278 receives RF signal
  ↓
// ESP32 converts RF to digital data
  ↓
// ESP32 sends data to phone via USB OTG
  ↓
// App processes and displays message to user
```

---

## 🔌 Communication Protocol

### **USB OTG Serial Communication**

#### **Commands: Phone → Hardware**
```
Command Format: COMMAND:DATA\n

Examples:
- PTT_START           → Start transmitting voice
- PTT_STOP            → Stop transmitting voice
- LORA_SEND:Hello!    → Send text message
- EMERGENCY:FIRE      → Send emergency signal
- INIT                → Initialize hardware
```

#### **Responses: Hardware → Phone**
```
Response Format: STATUS:DATA\n

Examples:
- STATUS:NAME=TULONG,FW=1.0.0,BAT=85,SIG=75
- LORA:CONNECTED      → LoRa module ready
- LORA:TRANSMITTING   → Currently transmitting
- LORA:RECEIVING      → Currently receiving
- BATTERY:85          → Battery level 85%
- SIGNAL:75           → Signal strength 75%
- AUDIO:DATA...       → Received audio data
- MESSAGE:Hello!      → Received text message
- EMERGENCY:FIRE      → Received emergency signal
```

---

## 🎤 Voice Communication Flow

### **Half-Duplex PTT (Push-to-Talk)**

#### **Transmitting:**
```
1. User presses PTT button in app
2. App starts recording from phone microphone
3. App compresses audio (codec: Opus/ADPCM)
4. App sends audio chunks to ESP32 via USB OTG
5. ESP32 modulates and transmits via SX1278
6. User releases PTT button
7. App stops recording and transmission
```

#### **Receiving:**
```
1. SX1278 receives RF signal
2. ESP32 demodulates and sends to phone via USB OTG
3. App receives audio chunks
4. App decompresses audio
5. App plays through phone speaker
```

---

## 🕸️ Mesh Networking

### **App-Controlled Mesh**
- **Routing:** App manages mesh routes
- **Node Discovery:** App scans for nearby nodes
- **Message Forwarding:** App decides which messages to relay
- **Network Map:** App maintains network topology

```
Phone 1 ←─── USB ───→ ESP32 ←─── RF ───→ ESP32 ←─── USB ───→ Phone 2
  ↓                                                              ↓
App controls                                              App controls
everything                                                everything
```

---

## ⚡ Power Management

### **Hardware as Power Bank:**
- Phone draws power from ESP32 battery
- App monitors battery level via serial commands
- App displays battery status to user
- App warns when battery is low

---

## 🔧 Current Implementation Status

### ✅ **Completed:**
- `HardwareService` for ESP32 + SX1278 communication
- Mock mode for testing without hardware
- PTT button controlled from app
- Message sending from app
- Status monitoring (battery, signal, connection)
- Hardware management screen in app

### 🚧 **Ready for Real Hardware:**
- USB OTG serial communication interface
- Command protocol parser
- Audio streaming implementation
- Real-time status updates
- Error handling and recovery

### 📋 **TODO When Hardware is Ready:**
1. Implement actual USB OTG connection
2. Add audio codec (Opus/ADPCM)
3. Test RF range and reliability
4. Optimize for low latency
5. Implement mesh routing logic
6. Add encryption for security

---

## 🎯 Key Points

### **The Hardware is DUMB:**
- It's just an **RF transceiver**
- No intelligence, no decisions
- Pure signal conversion (digital ↔ RF)

### **The App is SMART:**
- All **UI controls**
- All **user interactions**
- All **audio processing**
- All **message routing**
- All **mesh logic**
- All **emergency handling**

### **Communication:**
- **Phone controls** everything
- **Hardware obeys** commands
- **USB OTG** is the connection
- **433MHz LoRa** is the RF link

---

## 📊 Data Flow Summary

```
USER ACTION (in app)
    ↓
APP PROCESSING
    ↓
USB OTG COMMAND to ESP32
    ↓
ESP32 SERIAL PARSER
    ↓
SX1278 RF TRANSMISSION (433MHz)
    ↓
    ~ ~ ~ AIR INTERFACE ~ ~ ~
    ↓
SX1278 RF RECEPTION (433MHz)
    ↓
ESP32 DATA CONVERSION
    ↓
USB OTG DATA to PHONE
    ↓
APP PROCESSING
    ↓
USER SEES/HEARS RESULT (in app)
```

---

## ✨ Summary

Your hardware setup is **perfect** for disaster communication:
- **Simple** hardware (ESP32 + SX1278)
- **Powerful** app (all controls and intelligence)
- **Flexible** (easy to update app without changing hardware)
- **Cost-effective** (hardware is just RF transceiver)
- **Reliable** (fewer components = fewer failure points)

The current implementation already follows this architecture! The `HardwareService` is designed to **control** the hardware, not to be controlled by it. All user interactions happen in the app, and the hardware simply executes RF commands. 🚀

