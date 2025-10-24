# ESP32 LoRa + Bluetooth + ADPCM Voice Bridge Integration Guide

## 🎯 System Overview

This system implements a **LoRa + Bluetooth (SPP) + ADPCM Voice Bridge** on ESP32-WROOM32 with SX1278, compatible with a **Flutter PTT app**.

### **Architecture Flow:**
```
Flutter App → Bluetooth SPP → ESP32 → ADPCM Encoding → LoRa → Other ESP32 → ADPCM Decoding → Bluetooth SPP → Flutter App
```

## 🔧 ESP32 Arduino Code Features

### **Key Components:**
- **Bluetooth SPP**: Receives Base64 PCM16LE from Flutter
- **ADPCM Encoding**: IMA ADPCM compression for LoRa transmission
- **LoRa Protocol**: Multi-packet voice transmission with CRC
- **Reassembly**: Voice message reconstruction from multiple packets
- **WAV Generation**: PCM to WAV conversion for playback

### **ESP32 Message Formats:**

#### **Receives from Flutter:**
```json
{
  "messageId": "ABC12345",
  "pcm16le_b64": "<base64_encoded_pcm16le_data>"
}
```

#### **Sends to Flutter:**
```json
{
  "type": "voice_message",
  "messageId": "ABC12345", 
  "from_node": "NODE_B",
  "data_b64_pcm16le": "<base64_encoded_pcm16le_data>"
}
```

## 📱 Flutter App Integration

### **Updated Components:**

#### **1. VoiceController (lib/controllers/voice_controller.dart)**
- ✅ **Sample Rate**: 8kHz (ESP32 compatible)
- ✅ **JSON Format**: Uses `pcm16le_b64` key (ESP32 compatible)
- ✅ **Voice Message Handler**: `handleVoiceMessage()` for receiving voice from ESP32
- ✅ **Debug Logging**: Status logs for voice transmission

#### **2. SimpleBluetoothService (lib/services/simple_bluetooth_service.dart)**
- ✅ **Voice Message Routing**: `_handleVoiceMessage()` for ESP32 voice messages
- ✅ **Message Type Detection**: Routes `voice_message` type to voice handler

#### **3. ESP32LoRaChatScreen (lib/screens/esp32_lora_chat_screen.dart)**
- ✅ **Voice Frame Format**: Direct ESP32 compatible JSON format
- ✅ **Voice Message Integration**: Automatic voice message handling

## 🚀 Expected Behavior

### **Sending Voice (Push-to-Talk):**
1. **Press & Hold PTT** → Flutter records PCM16LE at 8kHz
2. **Real-time Processing** → Chunks audio into frames
3. **Base64 Encoding** → Converts PCM to Base64
4. **Bluetooth Transmission** → Sends to ESP32 via SPP
5. **ESP32 Processing** → ADPCM encoding + LoRa transmission
6. **LoRa Broadcasting** → Multi-packet transmission to other nodes

### **Receiving Voice (Playback):**
1. **LoRa Reception** → ESP32 receives ADPCM packets
2. **Packet Reassembly** → Reconstructs complete voice message
3. **ADPCM Decoding** → Converts back to PCM16LE
4. **Bluetooth Transmission** → Sends Base64 PCM to Flutter
5. **Flutter Playback** → Decodes and plays voice message

## 🔍 Debug Logging

### **Flutter Debug Logs:**
```
[VOICE] 🎵 Received voice message from NODE_B (ID: ABC12345)
[VOICE] ✅ Voice message playback completed
[BT] 🎵 Voice message received from NODE_B (ID: ABC12345)
```

### **ESP32 Serial Logs:**
```
[VOICE] PCM 1600B -> ADPCM 800B, msgId=ABC12345
[LoRa] VC pkt 1/4 (msg ABC12345)
[LoRa] Voice complete (4 packets)
[BT] Sent voice_message 1600 PCM bytes to app
```

## 🧪 Testing Procedure

### **1. Hardware Setup:**
- Flash ESP32 with provided Arduino code
- Configure node names: `ESP32_Node_A`, `ESP32_Node_B`, `ESP32_Node_C`
- Ensure LoRa SX1278 wiring is correct
- Set frequency to 433 MHz

### **2. Flutter App Testing:**
- Build and install APK on Android device
- Connect to ESP32 via Bluetooth
- Test PTT recording and transmission
- Verify voice message reception and playback

### **3. Multi-Node Testing:**
- Set up 2+ ESP32 nodes with different names
- Test voice transmission between nodes
- Verify LoRa range and reliability
- Test simultaneous text and voice messaging

## 🔧 Configuration

### **ESP32 Settings:**
```cpp
#define FREQ 433E6                    // 433 MHz
#define BT_DEVICE_NAME "ESP32_Node_B" // Change per node
LoRa.setTxPower(17);                  // 17 dBm
LoRa.setSpreadingFactor(9);           // SF9
LoRa.setSignalBandwidth(125E3);      // 125 kHz
```

### **Flutter Settings:**
```dart
static const int sampleRate = 8000;   // 8kHz for ADPCM
static const int numChannels = 1;    // Mono
static const int frameSize = 800;    // ~100ms frames
```

## 🎯 Key Features

### **✅ Implemented:**
- **PCM16LE Recording**: 8kHz mono recording
- **Base64 Encoding**: ESP32 compatible format
- **Bluetooth SPP**: Reliable serial communication
- **ADPCM Compression**: Efficient LoRa transmission
- **Multi-packet Protocol**: Large voice message support
- **CRC Verification**: Data integrity checking
- **Voice Reassembly**: Complete message reconstruction
- **Real-time Playback**: Instant voice message playback

### **🔧 Technical Specifications:**
- **Audio Format**: PCM16LE, 8kHz, Mono
- **Compression**: IMA ADPCM (4:1 ratio)
- **LoRa Frequency**: 433 MHz
- **Packet Size**: 220 bytes max payload
- **CRC**: 16-bit CRC verification
- **Timeout**: 20-second voice session timeout

## 🚨 Troubleshooting

### **Common Issues:**
1. **No Voice Reception**: Check LoRa antenna and frequency
2. **Audio Quality**: Verify 8kHz sample rate
3. **Bluetooth Disconnection**: Check SPP connection stability
4. **Packet Loss**: Verify LoRa settings and range
5. **Playback Issues**: Check Base64 decoding

### **Debug Commands:**
```bash
# Monitor ESP32 serial output
screen /dev/ttyUSB0 115200

# Check Flutter logs
flutter logs

# Test Bluetooth connection
bluetoothctl
```

## 📊 Performance Metrics

### **Expected Performance:**
- **Latency**: < 2 seconds end-to-end
- **Range**: 1-5 km (depending on terrain)
- **Quality**: Good voice quality with ADPCM
- **Reliability**: CRC-verified transmission
- **Battery**: Optimized for mobile use

This integration provides a complete **LoRa + Bluetooth + ADPCM Voice Bridge** system for long-range voice communication between ESP32 nodes and Flutter mobile apps.
