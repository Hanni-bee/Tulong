# 🔧 ESP32 Firmware Fix - Text Message Format

## 🐛 **Problem Identified**

Looking at your Arduino code, I found the issue:

### **Current Behavior:**

1. **SOS/Emergency Messages (VTYPE_SOS = 0xA1):**
   ```cpp
   // Creates JSON and sends
   StaticJsonDocument<512> doc;
   doc["type"] = "group";
   doc["message"] = textBuffer;
   doc["is_emergency"] = true;
   serializeJson(doc, jsonOutput);
   SerialBT.println(jsonOutput);  // ✅ Sends as JSON
   ```

2. **Regular Text Messages (VTYPE_TEXT = 0xA0):**
   ```cpp
   // Sends as plain text
   SerialBT.println(textBuffer);  // ❌ Sends as plain text, NOT JSON!
   ```

### **The Issue:**
- Flutter app expects JSON format with `type` and `message` fields
- Regular text messages are sent as plain text
- Flutter tries to parse as JSON → fails → goes to plain text handler
- Plain text handler might filter it or process incorrectly

## ✅ **Solution: Update ESP32 Code**

Change the regular text message handling to send JSON format (like SOS messages):

### **In `handleRfPacket()` function, find this section:**

```cpp
// ----------------- TEXT PACKET HANDLING (0xA0) -----------------
if (hdr->type == VTYPE_TEXT) {
  // ... existing code ...
  
  // Check if this is the last packet (if payload is less than 28, it's likely the last)
  if (payLen < 28) {
    // Deliver text to phone
    SerialBT.println(textBuffer);  // ❌ CHANGE THIS
    logEvent("RF", "Text forwarded: " + textBuffer);
    rxText = false;
    textBuffer = "";
  }
  return;
}
```

### **Replace with:**

```cpp
// ----------------- TEXT PACKET HANDLING (0xA0) -----------------
if (hdr->type == VTYPE_TEXT) {
  uint16_t seq = hdr->seq;
  uint8_t payLen = len - sizeof(VoiceHdr);

  // First packet of text
  if (!rxText) {
    textBuffer = "";
    textExpect = seq;
    rxText = true;
  }

  // Sequence check
  if (seq != textExpect) {
    logEvent("RF_LOSS", String("TEXT out of order: got=") + seq + " expect=" + textExpect);
    textExpect = seq + 1;   // continue anyway
  } else {
    textExpect++;
  }

  // Append payload
  textBuffer += String((char*)(raw + sizeof(VoiceHdr)), payLen);

  // Check if this is the last packet (if payload is less than 28, it's likely the last)
  if (payLen < 28) {
    // ✅ FIX: Send as JSON format (like SOS messages)
    StaticJsonDocument<512> doc;
    doc["type"] = "group";
    doc["message"] = textBuffer;
    doc["is_emergency"] = false;
    doc["timestamp"] = millis();
    
    // Try to extract sender_name if present in textBuffer (if it was JSON originally)
    // Otherwise, use default
    String jsonOutput;
    serializeJson(doc, jsonOutput);
    SerialBT.println(jsonOutput);
    logEvent("RF", "Text forwarded (JSON): " + textBuffer);
    rxText = false;
    textBuffer = "";
  }
  return;
}
```

## 📝 **Complete Updated Section**

Here's the complete updated `handleRfPacket()` section for TEXT handling:

```cpp
// ----------------- TEXT PACKET HANDLING (0xA0) -----------------
if (hdr->type == VTYPE_TEXT) {
  uint16_t seq = hdr->seq;
  uint8_t payLen = len - sizeof(VoiceHdr);

  // First packet of text
  if (!rxText) {
    textBuffer = "";
    textExpect = seq;
    rxText = true;
  }

  // Sequence check
  if (seq != textExpect) {
    logEvent("RF_LOSS", String("TEXT out of order: got=") + seq + " expect=" + textExpect);
    textExpect = seq + 1;   // continue anyway
  } else {
    textExpect++;
  }

  // Append payload
  textBuffer += String((char*)(raw + sizeof(VoiceHdr)), payLen);

  // Check if this is the last packet
  if (payLen < 28) {
    // ✅ Send as JSON format to match Flutter expectations
    StaticJsonDocument<512> doc;
    doc["type"] = "group";
    doc["message"] = textBuffer;
    doc["is_emergency"] = false;
    doc["timestamp"] = millis();
    
    String jsonOutput;
    serializeJson(doc, jsonOutput);
    SerialBT.println(jsonOutput);
    logEvent("RF", "Text forwarded (JSON): " + textBuffer);
    rxText = false;
    textBuffer = "";
  }
  return;
}
```

## 🎯 **Why This Fixes It**

1. **Consistent Format:** Both regular text and SOS messages now send JSON
2. **Flutter Compatibility:** Flutter can parse JSON and extract `type` and `message` fields
3. **Proper Processing:** Messages go through `_processIncomingMapMessage()` which handles them correctly
4. **No Filtering Issues:** Valid JSON messages are never filtered as debug logs

## 📋 **Steps to Apply Fix**

1. Open your Arduino IDE
2. Find the `handleRfPacket()` function
3. Locate the `VTYPE_TEXT` handling section
4. Replace the `SerialBT.println(textBuffer);` line with the JSON format code above
5. Upload to ESP32
6. Test message sending/receiving

## ⚠️ **Note**

You'll need to add this at the top of your Arduino file if not already present:
```cpp
#include <ArduinoJson.h>
```

Make sure you have the ArduinoJson library installed in Arduino IDE.

