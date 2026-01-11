# ESP32 Node B - Updated Code Setup Guide

## ✅ Changes from Node A

The Node B code (`ESP32_NodeB_UPDATED.ino`) is identical to Node A except for the following key differences:

### 1. Bluetooth Device Name
```cpp
#define BT_DEVICE_NAME "ESP32_NodeB_Voice"  // Node A uses "ESP32_NodeA_Voice"
```

### 2. Pipe Address Configuration (CRITICAL)
**Node A:**
- Writes to: `address[0]` ("1Node")
- Reads on: `address[1]` ("2Node")

**Node B:**
- Writes to: `address[1]` ("2Node") - **OPPOSITE**
- Reads on: `address[0]` ("1Node") - **OPPOSITE**

This ensures bidirectional communication:
- Node A sends → Node B receives
- Node B sends → Node A receives

### 3. All Other Features Match Node A
- ✅ JSON format for all text messages (regular and emergency)
- ✅ Debug log filtering (CRC errors won't appear as messages)
- ✅ Voice message support
- ✅ SOS/Emergency message support
- ✅ Same RF channel (108), data rate (250KBPS), and PA level
- ✅ Same CRC8 calculation
- ✅ Same packet structure and sequence handling

## 📋 Installation Steps

1. **Open Arduino IDE**
2. **Select Board**: Tools → Board → ESP32 Dev Module
3. **Select Port**: Tools → Port → [Your ESP32 Node B port]
4. **Install Required Libraries** (if not already installed):
   - `RF24` by TMRh20
   - `ArduinoJson` by Benoit Blanchon
   - ESP32 BluetoothSerial (built-in with ESP32 core)
5. **Copy Code**: Open `ESP32_NodeB_UPDATED.ino`
6. **Upload**: Click Upload button
7. **Verify**: Open Serial Monitor (115200 baud) and check for:
   ```
   === ESP32 Voice Bridge (Node B: nRF24 + SPP) WITH SOS ===
   Bluetooth Ready: ESP32_NodeB_Voice
   ✅ Ready @ ch=108 dataRate=250k PA=LOW
   ```

## 🔧 Hardware Configuration

- **CE Pin**: 26
- **CSN Pin**: 27
- **nRF24L01**: Connected via SPI
- **Bluetooth**: Built-in ESP32 Bluetooth

## ✅ Testing Checklist

- [ ] Node B connects to phone via Bluetooth
- [ ] Node B receives messages from Node A (via nRF24)
- [ ] Node B sends messages to Node A (via nRF24)
- [ ] Regular text messages work in both directions
- [ ] Emergency/SOS messages work in both directions
- [ ] Voice messages work in both directions
- [ ] No debug logs appearing as chat messages
- [ ] JSON format messages are properly parsed by Flutter app

## 🐛 Troubleshooting

### No Communication Between Nodes
- Verify both nodes are on the same RF channel (108)
- Check nRF24L01 wiring (CE, CSN, SPI pins)
- Verify pipe addresses are correctly configured (opposite directions)
- Check power supply (nRF24L01 needs stable 3.3V)

### CRC Errors
- Check nRF24L01 antenna connections
- Verify distance between nodes (should be within range)
- Check for interference on 2.4GHz band
- Verify power supply stability

### Messages Not Appearing in Flutter App
- Ensure both nodes are updated with the new code
- Check that Flutter app is using the updated APK (with JSON parsing fixes)
- Verify Bluetooth connection status in Flutter app
- Check Serial Monitor for JSON format messages being sent

