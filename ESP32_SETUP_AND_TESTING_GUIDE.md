# 🔧 ESP32 + SX1278 Setup and Testing Guide

## 📋 **Kailangan Mong Materials:**

### **Hardware:**
- ✅ ESP32 WROOM 32 development board
- ✅ SX1278 LoRa module (433MHz)
- ✅ Antenna for SX1278 (433MHz)
- ✅ USB OTG cable (for phone connection)
- ✅ Jumper wires
- ✅ Breadboard (optional)
- ✅ Battery (Li-ion 3.7V or power bank)

### **Software:**
- ✅ Arduino IDE (with ESP32 board support)
- ✅ LoRa library
- ✅ TULONG APK (already built!)

---

## 🔌 **Step 1: Hardware Wiring**

### **SX1278 LoRa → ESP32 Connections:**

```
SX1278 Pin  →  ESP32 Pin
─────────────────────────
VCC         →  3.3V
GND         →  GND
SCK         →  GPIO 5
MISO        →  GPIO 19
MOSI        →  GPIO 27
NSS/CS      →  GPIO 18
RESET       →  GPIO 14
DIO0        →  GPIO 26
```

### **Wiring Diagram:**
```
           ESP32 WROOM 32
         ┌────────────────┐
    3.3V │ 1          30 │ GND
         │                │
GPIO 5   │ 2  (SCK)   29 │ GPIO 19 (MISO)
GPIO 18  │ 3  (CS)    28 │ GPIO 27 (MOSI)
GPIO 14  │ 4  (RST)   27 │ GPIO 26 (DIO0)
         │                │
         │     [USB]      │ ← Connect to phone
         └────────────────┘
              │
              ↓
           SX1278 LoRa Module
         ┌────────────────┐
         │  VCC  → 3.3V   │
         │  GND  → GND    │
         │  SCK  → GPIO5  │
         │  MISO → GPIO19 │
         │  MOSI → GPIO27 │
         │  CS   → GPIO18 │
         │  RST  → GPIO14 │
         │  DIO0 → GPIO26 │
         │  ANT  → Antenna│
         └────────────────┘
```

**⚠️ IMPORTANT:**
- **Use 3.3V** for SX1278 (NOT 5V!)
- **Connect antenna** to SX1278 before powering on
- **Never transmit** without antenna (damage possible!)

---

## 💻 **Step 2: Install Arduino IDE & Libraries**

### **A. Download Arduino IDE:**
1. Go to: https://www.arduino.cc/en/software
2. Download latest version
3. Install

### **B. Add ESP32 Board Support:**
1. Open Arduino IDE
2. Go to **File → Preferences**
3. In "Additional Board Manager URLs", add:
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
4. Click **OK**
5. Go to **Tools → Board → Boards Manager**
6. Search for "ESP32"
7. Install "**esp32 by Espressif Systems**"

### **C. Install LoRa Library:**
1. Go to **Sketch → Include Library → Manage Libraries**
2. Search for "**LoRa by Sandeep Mistry**"
3. Click **Install**

---

## 📝 **Step 3: Upload Firmware to ESP32**

### **A. Open the Firmware:**
1. Open Arduino IDE
2. Click **File → Open**
3. Navigate to `esp32_tulong_firmware/esp32_tulong_firmware.ino`
4. Click **Open**

### **B. Configure Arduino IDE:**
1. Go to **Tools → Board → ESP32 Arduino**
2. Select "**ESP32 Dev Module**"
3. Go to **Tools → Upload Speed**
4. Select "**115200**"
5. Go to **Tools → Port**
6. Select the COM port where ESP32 is connected

### **C. Upload:**
1. Connect ESP32 to computer via USB
2. Click **Upload** button (→ arrow)
3. Wait for "**Done uploading**" message

### **D. Verify:**
1. Click **Tools → Serial Monitor**
2. Set baud rate to **115200**
3. You should see:
   ```
   STATUS:Initializing TULONG Hardware...
   LORA:CONNECTED
   STATUS:TULONG Hardware Ready!
   ```

---

## 📱 **Step 4: Connect to Android Phone**

### **A. Prepare Phone:**
1. Install TULONG APK on phone
2. Enable **USB OTG** in phone settings (if available)
3. Make sure phone supports USB OTG

### **B. Connect Hardware:**
1. Disconnect ESP32 from computer
2. Connect ESP32 to phone using **USB OTG cable**
3. Phone should recognize device

### **C. Open TULONG App:**
1. Launch TULONG app
2. Sign in or create account
3. Navigate to **Hardware** tab (bottom navigation)

---

## 🧪 **Step 5: Testing**

### **Test 1: Hardware Connection**
1. Open **Hardware** screen in app
2. You should see:
   - ✅ Hardware Connected
   - ✅ Device Name: TULONG_ESP32
   - ✅ Firmware: 1.0.0
   - ✅ LoRa: Ready

### **Test 2: Send Test Message**
1. In **Hardware** screen, tap "**Send Test Message**"
2. You should see in Serial Monitor:
   ```
   DEBUG:Received command: LORA_SEND:Hello from TULONG App!
   STATUS:Message sent via LoRa
   ```
3. If you have **2 devices**, the other device should receive the message!

### **Test 3: Push-to-Talk (PTT)**
1. Go to **Walkie Talkie** screen
2. Press and hold the **microphone button**
3. Speak into phone
4. Release button
5. Serial Monitor should show:
   ```
   DEBUG:Received command: PTT_START
   LORA:TRANSMITTING
   DEBUG:Received command: PTT_STOP
   LORA:CONNECTED
   ```

### **Test 4: Receive Message (2 devices needed)**
**Device A:**
1. Go to Hardware screen
2. Tap "Send Test Message"

**Device B:**
1. Should automatically receive message
2. Message appears in app
3. Serial Monitor shows:
   ```
   LORA:RECEIVING
   MESSAGE:Hello from TULONG App!
   LORA:CONNECTED
   ```

### **Test 5: Emergency Signal**
1. In Home screen, tap **Emergency** button
2. Select emergency type
3. Confirm
4. Serial Monitor should show:
   ```
   DEBUG:Received command: EMERGENCY:FIRE
   STATUS:Emergency signal sent
   ```
5. All nearby devices should receive emergency alert!

---

## 🔍 **Troubleshooting**

### **Problem: ESP32 won't upload**
**Solution:**
- Hold **BOOT** button on ESP32 while clicking Upload
- Try different USB cable
- Check drivers are installed

### **Problem: LoRa initialization failed**
**Solution:**
- Check all wiring connections
- Verify 3.3V power (not 5V!)
- Make sure antenna is connected
- Try different SX1278 module

### **Problem: Phone doesn't recognize device**
**Solution:**
- Check USB OTG cable
- Verify phone supports OTG
- Try different USB cable
- Restart phone

### **Problem: App shows "Hardware Offline"**
**Solution:**
- Make sure ESP32 is powered on
- Check USB connection
- Restart app
- Check Serial Monitor for errors

### **Problem: Messages not received**
**Solution:**
- Check antenna connection on both devices
- Verify both using same frequency (433MHz)
- Check distance (start close, then move apart)
- Check for obstacles (walls, metal)

---

## 📊 **Serial Monitor Commands for Testing**

You can also test by typing commands directly in Serial Monitor:

### **Test Commands:**
```
INIT                        → Get device info
STATUS                      → Get current status
PTT_START                   → Simulate PTT start
PTT_STOP                    → Simulate PTT stop
LORA_SEND:Test message      → Send test message
EMERGENCY:FIRE              → Send emergency signal
```

### **Expected Responses:**
```
STATUS:NAME=TULONG_ESP32,FW=1.0.0,BAT=85,SIG=-45
LORA:CONNECTED
LORA:TRANSMITTING
LORA:RECEIVING
BATTERY:85
SIGNAL:75
MESSAGE:Received text
```

---

## ✅ **Success Checklist**

Before declaring success, verify:

- [ ] ESP32 firmware uploads without errors
- [ ] Serial Monitor shows "LORA:CONNECTED"
- [ ] Phone recognizes ESP32 via USB OTG
- [ ] App shows "Hardware Connected"
- [ ] Battery and signal levels update
- [ ] Test message sends successfully
- [ ] PTT button shows "TRANSMITTING" state
- [ ] (With 2 devices) Messages received successfully
- [ ] Emergency signal works

---

## 🚀 **Next Steps After Testing**

### **1. Range Testing:**
- Start with devices 10m apart
- Gradually increase distance
- Note maximum range
- Test in different environments

### **2. Voice Quality:**
- Test PTT voice transmission
- Check audio clarity
- Measure latency
- Adjust codec settings if needed

### **3. Mesh Networking:**
- Test with 3+ devices
- Verify message routing
- Test relay functionality
- Map network topology

### **4. Battery Life:**
- Test continuous operation time
- Measure power consumption
- Test while charging phone
- Optimize sleep modes

---

## 📞 **Common Usage Scenarios**

### **Scenario 1: Emergency Broadcast**
```
1. User taps Emergency button in app
2. App sends: EMERGENCY:FIRE
3. ESP32 transmits via LoRa (3 times)
4. All devices within range receive alert
5. Devices show emergency notification
```

### **Scenario 2: Voice Communication**
```
1. User presses PTT button in app
2. App sends: PTT_START
3. App streams audio to ESP32
4. ESP32 transmits via LoRa
5. Other devices receive and play audio
6. User releases button
7. App sends: PTT_STOP
```

### **Scenario 3: Text Messaging**
```
1. User types message in Chat
2. App sends: LORA_SEND:Hello!
3. ESP32 transmits via LoRa
4. Other devices receive message
5. Devices display in chat screen
```

---

## 🎯 **Performance Targets**

### **Expected Performance:**
- **Range (Line of Sight):** 2-10 km
- **Range (Urban):** 500m - 2km
- **Message Latency:** < 1 second
- **Voice Latency:** < 500ms
- **Battery Life:** 8-12 hours continuous
- **Max Devices:** 50+ in mesh network

---

## 💡 **Tips for Best Results**

1. **Always connect antenna** before powering on
2. **Use quality USB OTG cable** (some cheap cables don't work)
3. **Start testing close** (1-2 meters) before increasing distance
4. **Keep firmware updated** as we improve it
5. **Monitor battery** when testing extensively
6. **Test outdoors** for maximum range
7. **Avoid metal obstacles** when testing RF

---

## 📝 **Notes**

- Current firmware is **version 1.0** - basic functionality
- Audio streaming will be added in future updates
- Mesh networking logic is in the app (firmware just relays)
- Encryption will be added for security
- More diagnostics will be added

---

## ✨ **Summary**

**Plug-and-play AFTER first-time setup:**

1. ✅ Upload firmware to ESP32 (one time only)
2. ✅ Wire SX1278 to ESP32 (one time only)
3. ✅ After that, just plug USB OTG to phone!
4. ✅ App automatically detects and connects!

**Good luck with testing! 🚀**

