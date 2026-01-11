/*
 * ESP32 nRF24L01 + Bluetooth SPP Voice Bridge (Node B) - WITH SOS SUPPORT - UPDATED
 * 
 * Phone (Flutter)   <—SPP—>   ESP32 Node B (this file)   <—nRF24—>   ESP32 Node A   <—SPP—>   Phone
 *
 * App protocol:
 *   Text: Plain string or JSON with is_emergency flag
 *   Voice: <VOICE_START>\n, <base64 lines>, <VOICE_END>\n
 *
 * RF payload (max 32B): 3B header + 1B CRC + up to 28 ASCII chars
 *   struct VoiceHdr { uint8_t type; uint16_t seq; uint8_t crc8; }
 *   type: 0xD0 = START, 0xD1 = DATA, 0xD2 = END, 0xA0 = TEXT, 0xA1 = SOS/EMERGENCY
 */

#include <SPI.h>
#include <nRF24L01.h>
#include <RF24.h>
#include "BluetoothSerial.h"
#include <ArduinoJson.h>

// ----------------- Pins / Config -----------------
#define CE_PIN         26
#define CSN_PIN        27
#define BT_DEVICE_NAME "ESP32_NodeB_Voice"

RF24 radio(CE_PIN, CSN_PIN);
BluetoothSerial SerialBT;

// 5-byte addresses (pipe names). index 0 = Node A (peer), index 1 = Node B (this).
// NOTE: Node B uses OPPOSITE pipe directions from Node A
const byte address[][6] = {"1Node", "2Node"};

// nRF settings
#define RF_CHANNEL     108          // 2.508 GHz (must match Node A)
#define RF_DATARATE    RF24_250KBPS // robust; try RF24_1MBPS if you want faster
#define RF_PALEVEL     RF24_PA_LOW  // PA_MAX needs strong 3V3 + decoupling

// ----------------- Voice RF header -----------------
enum : uint8_t { 
  VTYPE_START = 0xD0, 
  VTYPE_DATA = 0xD1, 
  VTYPE_END = 0xD2,
  VTYPE_TEXT = 0xA0,
  VTYPE_SOS = 0xA1   // Emergency/SOS message type
};

struct __attribute__((packed)) VoiceHdr {
  uint8_t  type;   // VTYPE_*
  uint16_t seq;    // little-endian
  uint8_t  crc8;   // CRC-8 over [type|seq(2)|payload]
};
  
// ----------------- State -----------------
String   incomingBuffer = "";  // collects Base64 for a single VM
bool     isVoice = false;      // in "voice streaming" mode over BT
uint16_t g_txSeq = 0;          // RF sequence counter per VM

bool     rxVoice = false;      // RX reassembly state
uint16_t rxExpect = 0;         // next expected RF seq
bool    txVoice = false;          // true while we are transmitting voice
unsigned long txLastEnd = 0;   // last time a voice TX ended

// --- Timeout tracker for voice reception ---
unsigned long lastRxMillis = 0;
const unsigned long VOICE_TIMEOUT = 3000; // milliseconds before assuming end

// Text reassembly state
bool     rxText = false;
uint16_t textExpect = 0;
String   textBuffer = "";

// ----------------- Logging Helper -----------------
void logEvent(const String &tag, const String &msg) {
  String log = "[" + String(millis()) + "][" + tag + "] " + msg;
  Serial.println(log);
  SerialBT.println(log);
}

// ----------------- CRC8 (polynomial 0x07, init 0x00) -----------------
uint8_t crc8_calc(const uint8_t* data, size_t len) {
  uint8_t crc = 0x00;
  for (size_t i = 0; i < len; i++) {
    crc ^= data[i];
    for (uint8_t b = 0; b < 8; b++) {
      if (crc & 0x80) crc = (crc << 1) ^ 0x07;
      else            crc <<= 1;
    }
  }
  return crc;
}

// ----------------- nRF helpers -----------------
bool sendRfRaw(const void* buf, uint8_t len) {
  if (len == 0 || len > 32) return false;

  radio.stopListening();

  // FAST TRY
  if (radio.write(buf, len)) {
    radio.startListening();
    delay(10);
    return true;
  }

  // SLOW MODE — retry up to 7 seconds
  unsigned long start = millis();
  while (millis() - start < 7000) {
    if (radio.write(buf, len)) {
      radio.startListening();
      delay(10);
      return true;
    }
    delay(50);
  }

  // ---- FAIL + FULL RF RESET ----
  radio.stopListening();
  radio.flush_tx();
  radio.flush_rx();
  radio.clearStatusFlags();
  delay(5);
  radio.startListening();

  return false;
}

// Send text packet (regular or emergency)
bool sendTextPacket(const String &msg, bool isEmergency = false) {
    int N = msg.length();
    uint8_t msgType = isEmergency ? VTYPE_SOS : VTYPE_TEXT;
    
    for (int i = 0; i < N; i += 28) {
        uint8_t L = min(28, N - i);

        uint8_t buf[4 + 28];
        VoiceHdr *hdr = (VoiceHdr*)buf;
        hdr->type = msgType;
        hdr->seq  = i / 28;

        memcpy(buf + sizeof(VoiceHdr), msg.c_str() + i, L);
        hdr->crc8 = crc8_calc(buf, sizeof(VoiceHdr) + L - 1);

        if (!sendRfRaw(buf, sizeof(VoiceHdr) + L)) return false;
    }
    return true;
}

bool channelBusy() {
  // Simple approach: check if we're receiving something or just finished TX recently
  if (radio.testCarrier()) return true; // detects RF activity on the channel
  if (rxVoice) return true;             // someone else is talking
  if (millis() - txLastEnd < 300) return true; // brief cooldown after TX
  return false;
}

bool sendVoiceControl(uint8_t type) {
  // Sends START or END with just header+crc (no payload)
  uint8_t buf[sizeof(VoiceHdr)] = {0};
  VoiceHdr* hdr = (VoiceHdr*)buf;
  hdr->type = type;
  hdr->seq  = 0;         // ignored for control packets
  hdr->crc8 = crc8_calc(buf, 3); // CRC over type+seq (no payload)
  const bool ok = sendRfRaw(buf, sizeof(VoiceHdr));
  return ok;
}

// Flexible: splits any input line into ≤28-char RF packets, each with seq+CRC
bool sendVoiceLineWithSeq(const String& base64Line) {
  const int N = base64Line.length();
  int i = 0;
  while (i < N) {
    const uint8_t L = (uint8_t) min(28, N - i);

    uint8_t buf[4 + 28];                 // 3B hdr + 1B crc + payload
    VoiceHdr* hdr = (VoiceHdr*)buf;
    hdr->type = VTYPE_DATA;
    hdr->seq  = g_txSeq;

    memcpy(buf + sizeof(VoiceHdr), base64Line.c_str() + i, L);

    // compute CRC over type|seq|payload (exclude crc8 byte itself)
    hdr->crc8 = crc8_calc(buf, sizeof(VoiceHdr) + L - 1);

    const bool ok = sendRfRaw(buf, sizeof(VoiceHdr) + L);
    g_txSeq++;
    i += L;

    if (!ok) return false;   // early out if radio write failed
    delay(5);                // gentle pacing
  }
  return true;
}

// Parse JSON message and extract emergency flag
bool parseJsonMessage(const String &jsonStr, String &message, bool &isEmergency) {
  StaticJsonDocument<512> doc;
  DeserializationError error = deserializeJson(doc, jsonStr);
  
  if (error) {
    // Not JSON, treat as plain text
    message = jsonStr;
    isEmergency = false;
    return false;
  }
  
  // Extract message text
  if (doc.containsKey("message")) {
    message = doc["message"].as<String>();
  } else {
    message = jsonStr; // Fallback to original if no message field
  }
  
  // Check for emergency flag
  isEmergency = doc["is_emergency"] | false;
  
  return true;
}

// ----------------- RF receive handler -----------------
void handleRfPacket() {
  uint8_t len = radio.getDynamicPayloadSize();
  if (len == 0 || len > 32) { radio.flush_rx(); return; }

  uint8_t raw[32];
  radio.read(raw, len);
  lastRxMillis = millis(); // reset timeout timer on every received packet

  if (len >= sizeof(VoiceHdr)) {
    VoiceHdr* hdr = (VoiceHdr*)raw;
    // Verify CRC
    uint8_t crcGot = hdr->crc8;
    hdr->crc8 = 0; // clear for recompute
    uint8_t crcExpect = crc8_calc(raw, len -1);
    hdr->crc8 = crcGot;

    if (crcGot != crcExpect) {
      logEvent("RF_ERR", "CRC mismatch, dropping packet");
      return;
    }

    if (hdr->type == VTYPE_START) {
      rxVoice = true; rxExpect = 0; incomingBuffer = "";
      logEvent("RF", "V-START");
      if (txVoice) {
        txVoice = false; isVoice = false;
        SerialBT.println("<VOICE_DENY_BUSY>"); // peer took the floor
      }
      return;
    }

    if (hdr->type == VTYPE_END) {
      rxVoice = false;
      logEvent("RF", "V-END → to Flutter");
      // Forward completed VM to phone
      SerialBT.println("<VOICE_START>");
      SerialBT.println(incomingBuffer);
      SerialBT.println("<VOICE_END>");
      incomingBuffer = "";
      return;
    }

    if (hdr->type == VTYPE_DATA) {
      const uint16_t seq = hdr->seq;
      const uint8_t  payLen = len - sizeof(VoiceHdr);

      if (!rxVoice) {
        logEvent("RF_WARN", "V-DATA while not in voice mode; dropping");
        return;
      }

      if (seq != rxExpect) {
        logEvent("RF_LOSS", String("Missing/out-of-order: got seq=")+seq+" expect="+rxExpect);
        rxExpect = seq + 1; // resync to continue
      } else {
        rxExpect++;
      }

      // Append ASCII Base64 to buffer
      incomingBuffer += String((char*)(raw + sizeof(VoiceHdr)), payLen);
      return;
    }

    // ----------------- TEXT PACKET HANDLING (0xA0) - FIXED ✅ -----------------
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
        // ✅ FIXED: Send as JSON format (like SOS messages) instead of plain text
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

    // ----------------- SOS/EMERGENCY PACKET HANDLING (0xA1) -----------------
    if (hdr->type == VTYPE_SOS) {
      uint16_t seq = hdr->seq;
      uint8_t payLen = len - sizeof(VoiceHdr);

      // First packet of emergency text
      if (!rxText) {
        textBuffer = "";
        textExpect = seq;
        rxText = true;
      }

      // Sequence check
      if (seq != textExpect) {
        logEvent("RF_LOSS", String("SOS out of order: got=") + seq + " expect=" + textExpect);
        textExpect = seq + 1;
      } else {
        textExpect++;
      }

      // Append payload
      textBuffer += String((char*)(raw + sizeof(VoiceHdr)), payLen);

      // Check if last packet
      if (payLen < 28) {
        // Forward emergency message to phone with JSON format
        StaticJsonDocument<512> doc;
        doc["type"] = "group";
        doc["message"] = textBuffer;
        doc["is_emergency"] = true;
        doc["timestamp"] = millis();
        
        String jsonOutput;
        serializeJson(doc, jsonOutput);
        SerialBT.println(jsonOutput);
        logEvent("RF", "🚨 SOS forwarded: " + textBuffer);
        rxText = false;
        textBuffer = "";
      }
      return;
    }

    // Unknown type: ignore
    logEvent("RF_WARN", "Unknown type packet");
    return;
  }

  // Legacy or plain text (no header)
  String text((char*)raw, len);

  if (text == "<VOICE_START>") {
    rxVoice  = true;
    rxExpect = 0;
    incomingBuffer = "";
    logEvent("RF", "Voice START (legacy)");
    return;
  }
  if (text == "<VOICE_END>") {
    rxVoice = false;
    logEvent("RF", "Voice END (legacy) → to Flutter");
    SerialBT.println("<VOICE_START>");
    SerialBT.println(incomingBuffer);
    SerialBT.println("<VOICE_END>");
    incomingBuffer = "";
    return;
  }

  if (!rxVoice) {
    // Legacy plain text - wrap as JSON
    StaticJsonDocument<256> doc;
    doc["type"] = "group";
    doc["message"] = text;
    doc["is_emergency"] = false;
    doc["timestamp"] = millis();
    
    String jsonOutput;
    serializeJson(doc, jsonOutput);
    SerialBT.println(jsonOutput);
    logEvent("RF", "Legacy text forwarded (JSON): " + text);
  }
}

// ----------------- Setup -----------------
void setup() {
  Serial.begin(115200);
  SerialBT.begin(BT_DEVICE_NAME);
  delay(800);

  logEvent("BOOT", "=== ESP32 Voice Bridge (Node B: nRF24 + SPP) WITH SOS ===");
  logEvent("BT", "Bluetooth Ready: " + String(BT_DEVICE_NAME));

  if (!radio.begin()) {
    logEvent("RF", "❌ nRF24L01 init failed! Check wiring/power.");
    while (true) delay(1000);
  }

  radio.setAutoAck(true);
  radio.enableDynamicPayloads();
  radio.enableAckPayload();
  radio.setPALevel(RF_PALEVEL);
  radio.setDataRate(RF_DATARATE);
  radio.setChannel(RF_CHANNEL);
  radio.setRetries(5, 15);

  // Pipe directions for Node B: TX to Node A (address[0]), RX on address[1] (this node)
  // NOTE: OPPOSITE from Node A!
  // Node A writes to address[0] and reads on address[1]
  // Node B writes to address[1] and reads on address[0]
  radio.openWritingPipe(address[1]);    // send to Node A (Node A reads on address[1])
  radio.openReadingPipe(1, address[0]); // receive on address[0] (Node A writes to address[0])
  radio.startListening();

  logEvent("RF", "✅ Ready @ ch="+String(RF_CHANNEL)+" dataRate="
    + (RF_DATARATE==RF24_250KBPS?"250k":"1M") + " PA="
    + (RF_PALEVEL==RF24_PA_MIN?"MIN":RF_PALEVEL==RF24_PA_LOW?"LOW":RF_PALEVEL==RF24_PA_HIGH?"HIGH":"MAX"));
}

// ----------------- Main Loop -----------------
void loop() {
  // RF receive
  if (radio.available()) {
    handleRfPacket();
  }

  static unsigned long lastDebug = 0;
  if (millis() - lastDebug > 3000) {
    lastDebug = millis();
    bool busy = channelBusy();
    Serial.println("[DBG] idleCheck: busy=" + String(busy) +
                   " txVoice=" + String(txVoice) +
                   " rxVoice=" + String(rxVoice) +
                   " millisSinceLastEnd=" + String(millis() - txLastEnd));
  }

  // Bluetooth receive
  if (SerialBT.available()) {
    String msg = SerialBT.readStringUntil('\n');
    msg.trim();
    if (msg.isEmpty()) return;

    if (msg == "<VOICE_START>") {
      logEvent("BT_RX", "Got <VOICE_START>, channelBusy=" + String(channelBusy()));
      if (channelBusy()) {
        SerialBT.println("<VOICE_DENY_BUSY>");
        return;
      }
      isVoice = true;
      txVoice = true;
      g_txSeq = 0;
      if (sendVoiceControl(VTYPE_START)) {
        SerialBT.println("<VOICE_READY>");
      } else {
        txVoice = false; isVoice = false;
        SerialBT.println("<VOICE_DENY_BUSY>");
      }
      return;
    }

    if (msg == "<VOICE_END>") {
      isVoice = false;

      if (txVoice) {
        txVoice = false;

        // Send END
        sendVoiceControl(VTYPE_END);

        // Allow last packets to settle
        delay(200);

        // FULL RADIO RESET
        radio.stopListening();
        radio.flush_tx();
        radio.flush_rx();
        radio.clearStatusFlags();
        delay(50);
        radio.startListening();

        txLastEnd = millis();
      }

      SerialBT.println("<VOICE_DONE>");
      return;
    }

    if (isVoice) {
      // For each Base64 line from app → split to ≤28 chars and send with seq
      sendVoiceLineWithSeq(msg);
    } else {
      // Try to parse as JSON first
      String messageText;
      bool isEmergency = false;
      bool isJson = parseJsonMessage(msg, messageText, isEmergency);
      
      if (isJson && isEmergency) {
        // Send as SOS/emergency type
        logEvent("BT", "🚨 Sending SOS: " + messageText);
        sendTextPacket(messageText, true); // true = emergency
      } else {
        // Send as regular text
        sendTextPacket(messageText, false);
      }
    }
  }

  // --- Timeout-based voice stream end detection ---
  if (rxVoice && (millis() - lastRxMillis > VOICE_TIMEOUT)) {
    rxVoice = false;
    logEvent("RF_WARN", "Timeout — assuming end of voice");
    if (incomingBuffer.length() > 0) {
      SerialBT.println("<VOICE_START>");
      SerialBT.println(incomingBuffer);
      SerialBT.println("<VOICE_END>");
      logEvent("BT", "Sent partial voice to Flutter (" + String(incomingBuffer.length()) + " chars)");
      incomingBuffer = "";
    }
  }
}

