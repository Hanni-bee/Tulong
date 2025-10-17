# ⚡ TULONG Quick Start Guide

## 🎯 **30-Minute Setup**

### **Ano ang gagawin:**
1. ✅ Wire ESP32 to SX1278 (10 min)
2. ✅ Upload firmware (5 min)
3. ✅ Install APK on phone (2 min)
4. ✅ Connect and test (5 min)
5. ✅ Test with 2nd device (8 min)

---

## 🔌 **1. WIRING (10 minutes)**

### **Kailangan mo:**
- ESP32 WROOM 32
- SX1278 LoRa module
- 8 jumper wires
- Antenna (433MHz)

### **Simple Wiring Table:**
```
Connect these:

SX1278          ESP32
─────────────────────
VCC      →      3.3V
GND      →      GND
SCK      →      Pin 5
MISO     →      Pin 19
MOSI     →      Pin 27
NSS      →      Pin 18
RST      →      Pin 14
DIO0     →      Pin 26
ANT      →      (Antenna)
```

### **⚠️ CRITICAL:**
- **USE 3.3V** (hindi 5V!)
- **ALWAYS attach antenna** before power on
- **Never transmit** without antenna

---

## 💻 **2. UPLOAD FIRMWARE (5 minutes)**

### **A. Install Arduino IDE:**
1. Download from: arduino.cc
2. Install
3. Open Arduino IDE

### **B. Add ESP32 Support:**
```
1. File → Preferences
2. Additional URLs: 
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
3. Tools → Board → Boards Manager
4. Search "ESP32" → Install
```

### **C. Install LoRa Library:**
```
1. Sketch → Include Library → Manage Libraries
2. Search "LoRa"
3. Install "LoRa by Sandeep Mistry"
```

### **D. Upload:**
```
1. Tools → Board → ESP32 Dev Module
2. Tools → Port → (Select COM port)
3. File → Open → esp32_tulong_firmware.ino
4. Click Upload button (→)
5. Wait for "Done uploading"
```

### **E. Verify:**
```
1. Tools → Serial Monitor
2. Set to 115200 baud
3. Should see:
   ✅ LORA:CONNECTED
   ✅ STATUS:TULONG Hardware Ready!
```

---

## 📱 **3. INSTALL APK (2 minutes)**

### **On your Android phone:**
```
1. Copy app-release.apk to phone
2. Open file
3. Allow "Install from unknown sources"
4. Install
5. Open TULONG app
```

---

## 🔗 **4. CONNECT (5 minutes)**

### **Connect hardware to phone:**
```
1. Get USB OTG cable
2. Disconnect ESP32 from computer
3. Connect ESP32 to phone via OTG
4. Phone should recognize device
```

### **In TULONG app:**
```
1. Open app
2. Sign in (or create account)
3. Navigate to Hardware tab (bottom right)
4. Should see: ✅ Hardware Connected
```

---

## 🧪 **5. BASIC TESTS**

### **Test 1: Hardware Status**
```
Location: Hardware screen
Check:
✅ Hardware Connected
✅ LoRa: Ready
✅ Battery: Shows percentage
✅ Signal: Shows strength
```

### **Test 2: Send Message**
```
1. Go to Hardware screen
2. Tap "Send Test Message"
3. Should see success message
```

### **Test 3: PTT (Voice)**
```
1. Go to Walkie Talkie screen
2. Press and hold microphone button
3. Should see "TRANSMITTING"
4. Release button
5. Should return to "Ready"
```

---

## 👥 **6. TWO DEVICE TEST (8 minutes)**

### **If you have 2 complete sets:**

**Device A Setup:**
```
1. Complete steps 1-4 above
2. Go to Walkie Talkie screen
3. Wait for Device B
```

**Device B Setup:**
```
1. Complete steps 1-4 above
2. Go to Walkie Talkie screen
```

**Test Communication:**
```
Device A:
1. Press and hold PTT button
2. Say "Test from Device A"
3. Release button

Device B:
✅ Should hear "Test from Device A"

Device B:
1. Press and hold PTT button
2. Say "Test from Device B"
3. Release button

Device A:
✅ Should hear "Test from Device B"
```

**Test Messaging:**
```
Device A:
1. Go to Chat screen
2. Type "Hello from A"
3. Send

Device B:
✅ Should receive "Hello from A"
```

---

## 🎉 **SUCCESS!**

### **If all tests pass:**
✅ **Hardware is working!**
✅ **App is connected!**
✅ **LoRa communication works!**
✅ **Ready for field testing!**

---

## ⚠️ **Quick Troubleshooting**

### **Problem: LoRa won't initialize**
```
Solution:
- Check all 8 wire connections
- Verify 3.3V (not 5V!)
- Antenna must be connected
- Try different SX1278 module
```

### **Problem: Phone doesn't detect**
```
Solution:
- Check USB OTG cable (try different one)
- Phone must support OTG
- Restart phone
- Restart app
```

### **Problem: No messages received**
```
Solution:
- Check antenna on BOTH devices
- Start 1 meter apart
- Verify both devices show "Connected"
- Check Serial Monitor for errors
```

---

## 📊 **Expected Performance**

### **In the same room:**
- ✅ 100% message delivery
- ✅ Clear voice quality
- ✅ < 1 second latency

### **Outdoor (line of sight):**
- ✅ 2-10 km range
- ✅ 95%+ message delivery
- ✅ Good voice quality

### **Urban environment:**
- ✅ 500m - 2km range
- ✅ 90%+ message delivery
- ✅ Acceptable voice quality

---

## 🚀 **Next Steps**

### **After successful testing:**

1. **Range Test:**
   - Start close (10m)
   - Gradually increase distance
   - Note maximum usable range

2. **Battery Test:**
   - Measure how long it lasts
   - Test with continuous use
   - Check power consumption

3. **Real-World Test:**
   - Test in actual disaster scenario
   - Multiple users
   - Different environments
   - Emergency features

4. **Mesh Test (3+ devices):**
   - Test message relay
   - Network coverage
   - Automatic routing

---

## 💡 **Pro Tips**

1. **Label your devices** (A, B, C...) to avoid confusion
2. **Keep spare batteries** charged
3. **Protect antenna** (it's fragile!)
4. **Test before disasters** happen
5. **Train users** on how to use
6. **Keep firmware updated**

---

## 📞 **Support**

### **If may problema:**
1. Check Serial Monitor (115200 baud)
2. Read error messages
3. Try basic tests first
4. Check wiring again
5. Test with known working device

---

## ✨ **Summary**

**After first setup, it's truly plug-and-play!**

```
NEXT TIME:
1. Connect ESP32 to phone via OTG ✅
2. Open TULONG app ✅
3. Start communicating! ✅

NO need to:
❌ Upload firmware again
❌ Configure anything
❌ Install drivers
❌ Change settings

JUST PLUG AND USE! 🚀
```

**Good luck! Padayon! 💪**

