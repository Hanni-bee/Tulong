/*
 * ESP32 LoRa + Bluetooth (SPP) + ADPCM Voice Bridge
 * Compatible with Flutter App PTT system
 * 
 * Node Roles:
 *   Node A → "ESP32_Node_A"
 *   Node B → "ESP32_Node_B"
 *   Node C → "ESP32_Node_C"
 *
 * LoRa Wiring:
 *   NSS  = 5
 *   MOSI = 23
 *   MISO = 19
 *   SCK  = 18
 *   RESET= 2
 *   DIO0 = 4
 *
 * LoRa: SX1278 @ 433 MHz
 */

#include <Arduino.h>
#include <BluetoothSerial.h>
#include <LoRa.h>
#include <ArduinoJson.h>
#include <vector>
#include <SPI.h>

// ✅ Base64 support (ESP32 core 3.x)
extern "C" {
  #include "libb64/cdecode.h"
  #include "libb64/cencode.h"
}

// ---------------- CONFIG ----------------
#define NSS 5
#define RST 2
#define DIO0 4
#define FREQ 433E6
#define BT_DEVICE_NAME "ESP32_Node_B"  // change per node

BluetoothSerial BT;
String nodeId = "";
String btBuf = "";
bool connected = false;

// ---------- LOGGING UTILITY ----------
void logLine(const char* tag, const String &msg) {
  unsigned long ms = millis();
  Serial.printf("[%08lu] %-10s %s\n", ms, tag, msg.c_str());
}

// ---------------- UTILITIES -------------
static uint16_t crc16(const uint8_t *buf, size_t len) {
  uint16_t crc = 0xFFFF;
  while (len--) {
    crc ^= *buf++;
    for (int i = 0; i < 8; ++i)
      crc = (crc & 1) ? (crc >> 1) ^ 0xA001 : (crc >> 1);
  }
  return crc;
}

static String makeMsgId() {
  uint32_t t = millis();
  uint32_t r = esp_random();
  char id[9];
  sprintf(id, "%08X", t ^ r);
  id[8] = '\0';
  return String(id);
}

// ----------- IMA ADPCM State ------------
struct IMAState {
  int16_t prevSample;
  int index;
};

static const int indexTable[16] = {-1,-1,-1,-1,2,4,6,8,-1,-1,-1,-1,2,4,6,8};
static const int stepTable[89] = {
  7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,
  73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,
  408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,
  1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,
  7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,
  22385,24623,27086,29794,32767
};

// ----------- Base64 helpers -------------
static std::vector<uint8_t> b64Decode(const String &in) {
  size_t inLen = in.length();
  std::vector<uint8_t> out((inLen * 3) / 4 + 8);
  base64_decodestate s;
  base64_init_decodestate(&s);
  int produced = base64_decode_block(in.c_str(), (int)inLen, (char*)out.data(), &s);
  if (produced < 0) produced = 0;
  out.resize((size_t)produced);
  return out;
}

static String b64Encode(const uint8_t *data, size_t len) {
  size_t outCap = (len * 4) / 3 + 8;
  std::vector<char> out(outCap);
  base64_encodestate s;
  base64_init_encodestate(&s);
  int n = base64_encode_block((const char*)data, (int)len, out.data(), &s);
  n += base64_encode_blockend(out.data() + n, &s);
  return String(out.data()).substring(0, n);
}

// ----------- ADPCM Codec ------------
class ADPCM {
public:
  static void encode(const int16_t *in, size_t n, std::vector<uint8_t> &out, IMAState &st) {
    out.clear();
    out.reserve((n + 1) / 2);
    bool have = false;
    uint8_t pending = 0;

    for (size_t i = 0; i < n; i++) {
      int diff = in[i] - st.prevSample;
      int sign = 0;
      if (diff < 0) { sign = 8; diff = -diff; }
      int step = stepTable[st.index];
      int delta = 0;
      int temp = step;
      if (diff >= temp) { delta |= 4; diff -= temp; }
      temp >>= 1;
      if (diff >= temp) { delta |= 2; diff -= temp; }
      temp >>= 1;
      if (diff >= temp) delta |= 1;

      int diffq = step >> 3;
      if (delta & 4) diffq += step;
      if (delta & 2) diffq += step >> 1;
      if (delta & 1) diffq += step >> 2;

      st.prevSample += sign ? -diffq : diffq;
      if (st.prevSample > 32767) st.prevSample = 32767;
      if (st.prevSample < -32768) st.prevSample = -32768;

      st.index += indexTable[delta | sign];
      if (st.index < 0) st.index = 0;
      if (st.index > 88) st.index = 88;

      uint8_t nib = (delta & 7) | (sign ? 8 : 0);
      if (!have) { pending = nib; have = true; }
      else { out.push_back((nib << 4) | (pending & 0x0F)); have = false; }
    }
    if (have) out.push_back(pending & 0x0F);
  }

  static void decode(const uint8_t *in, size_t n, std::vector<int16_t> &out, IMAState &st) {
    out.clear();
    out.reserve(n * 2);
    for (size_t i = 0; i < n; i++) {
      uint8_t b = in[i];
      for (int nib = 0; nib < 2; nib++) {
        uint8_t code = (nib == 0) ? (b & 0x0F) : ((b >> 4) & 0x0F);
        int sign = code & 8;
        int delta = code & 7;
        int step = stepTable[st.index];
        int diffq = step >> 3;
        if (delta & 4) diffq += step;
        if (delta & 2) diffq += step >> 1;
        if (delta & 1) diffq += step >> 2;
        st.prevSample += (sign ? -diffq : diffq);
        st.prevSample = constrain(st.prevSample, -32768, 32767);
        st.index = constrain(st.index + indexTable[code], 0, 88);
        out.push_back(st.prevSample);
      }
    }
  }
};

// ----------- VOICE REASSEMBLY BUFFER ----------
struct VoicePacket {
  String msgId;
  uint16_t totalPkts;
  uint16_t receivedPkts;
  std::vector<std::vector<uint8_t>> chunks;
  unsigned long lastActivity;
  bool active;
};

#define MAX_VOICE_SESSIONS 4
#define VOICE_TIMEOUT 20000
VoicePacket sessions[MAX_VOICE_SESSIONS];

int findSession(const String &mid) {
  for (int i = 0; i < MAX_VOICE_SESSIONS; i++)
    if (sessions[i].active && sessions[i].msgId == mid) return i;
  return -1;
}

int createSession(const String &mid, uint16_t totalPkts) {
  for (int i = 0; i < MAX_VOICE_SESSIONS; i++) {
    if (!sessions[i].active) {
      sessions[i].active = true;
      sessions[i].msgId = mid;
      sessions[i].totalPkts = totalPkts;
      sessions[i].receivedPkts = 0;
      sessions[i].chunks.assign(totalPkts, {});
      sessions[i].lastActivity = millis();
      return i;
    }
  }
  return -1;
}

void clearSession(int idx) {
  if (idx < 0 || idx >= MAX_VOICE_SESSIONS) return;
  sessions[idx].active = false;
  sessions[idx].chunks.clear();
}

// ----------- SEND VOICE VIA LORA ----------
static const int LORA_MAX_PAYLOAD = 50;  // Reduced for multi-packet testing

static void sendVoiceLoRa(const String &msgId, const std::vector<uint8_t> &adpcm) {
  uint16_t total = (adpcm.size() + LORA_MAX_PAYLOAD - 1) / LORA_MAX_PAYLOAD;
  for (uint16_t i = 0; i < total; i++) {
    size_t off = (size_t)i * LORA_MAX_PAYLOAD;
    size_t len = min((size_t)LORA_MAX_PAYLOAD, adpcm.size() - off);
    uint16_t c = crc16(&adpcm[off], len);

    LoRa.beginPacket();
    LoRa.print("VC");
    LoRa.print(msgId);
    LoRa.write((uint8_t)i);
    LoRa.write((uint8_t)total);
    LoRa.write((uint8_t)(c >> 8));
    LoRa.write((uint8_t)(c & 0xFF));
    LoRa.write(&adpcm[off], len);
    LoRa.endPacket();

    logLine("LORA_TX", String("Sent chunk ") + String(i + 1) + "/" + String(total) + " ID=" + msgId + " (" + String(len) + " bytes)");
    delay(25);
  }
}

// ----------- HANDLE BLUETOOTH MESSAGES ----------
static void handleBT(const String &msg) {
  if (msg.indexOf("\"voice_frame\"") > 0 || msg.indexOf("\"pcm16leb64\"") > 0 || msg.indexOf("\"audio_data\"") > 0) {
    logLine("BT_RX", "Voice frame received from app");

    DynamicJsonDocument doc(4096);
    if (deserializeJson(doc, msg)) {
      logLine("JSON_ERR", "Failed to parse incoming JSON");
      return;
    }

    String mid = doc["messageId"].as<String>();
    if (mid.isEmpty()) mid = makeMsgId();
    String b64 = "";
    
    // Try different field names that Flutter app might send
    if (doc.containsKey("pcm16leb64")) {
      b64 = doc["pcm16leb64"].as<String>();
    } else if (doc.containsKey("audio_data")) {
      b64 = doc["audio_data"].as<String>();
    } else if (doc.containsKey("data")) {
      b64 = doc["data"].as<String>();
    }
    
    if (b64.isEmpty()) {
      logLine("BT_WARN", "Empty audio frame - no valid audio data field found");
      return;
    }

    std::vector<uint8_t> pcmBytes = b64Decode(b64);
    if (pcmBytes.size() < 2) {
      logLine("BT_WARN", "Invalid PCM data size");
      return;
    }
    
    std::vector<int16_t> pcm;
    pcm.reserve(pcmBytes.size() / 2);
    for (size_t i = 0; i + 1 < pcmBytes.size(); i += 2)
      pcm.push_back((int16_t)((uint8_t)pcmBytes[i] | ((uint8_t)pcmBytes[i + 1] << 8)));

    IMAState st{0, 0};
    std::vector<uint8_t> adpcm;
    ADPCM::encode(pcm.data(), pcm.size(), adpcm, st);
    logLine("ADPCM_ENC", String("PCM→ADPCM OK (") + String(adpcm.size()) + " bytes)");

    sendVoiceLoRa(mid, adpcm);
    if (BT.hasClient()) BT.println("{\"ack\":\"voice_sent\"}");
    return;
  }

  if (msg.indexOf("\"message\":") > 0) {
    logLine("BT_RX", "Text message received");
    int end = msg.lastIndexOf('}');
    String out = (end > 0)
                   ? (msg.substring(0, end) + ",\"from_node\":\"" + nodeId + "\"}")
                   : msg;
    LoRa.beginPacket();
    LoRa.print(out);
    LoRa.endPacket();
    if (BT.hasClient()) BT.println("{\"ack\":\"text_sent\"}");
    logLine("LORA_TX", "Text message sent");
  }
}

// ----------- PROCESS LORA PACKETS -----------
static void processLoRa() {
  int sz = LoRa.parsePacket();
  if (!sz) return;

  std::vector<uint8_t> buf(sz);
  for (int i = 0; i < sz && LoRa.available(); i++) buf[i] = LoRa.read();

  // TEXT
  if (sz >= 2 && buf[0] != 'V' && buf[1] != 'C') {
    String msg((char*)buf.data(), sz);
    if (msg.indexOf(nodeId) > 0) return;
    if (connected && BT.hasClient()) BT.println(msg);
    logLine("LORA_RX", "Text message relayed");
    return;
  }

  // VOICE
  if (sz < 14 || buf[0] != 'V' || buf[1] != 'C') return;

  char midChars[9];
  memcpy(midChars, &buf[2], 8);
  midChars[8] = '\0';
  String msgId = String(midChars);

  uint8_t pktIdx = buf[10];
  uint8_t totalPkts = buf[11];
  uint16_t crcRecv = ((uint16_t)buf[12] << 8) | buf[13];
  const uint8_t *payload = &buf[14];
  size_t payloadLen = sz - 14;

  uint16_t crcCalc = crc16(payload, payloadLen);
  if (crcCalc != crcRecv) {
    logLine("LORA_ERR", (String("CRC mismatch pkt ") + String(pktIdx) + " ID=" + msgId).c_str());
    return;
  }

  int idx = findSession(msgId);
  if (idx == -1) idx = createSession(msgId, totalPkts);
  if (idx == -1) return;

  VoicePacket &v = sessions[idx];
  if (pktIdx >= v.totalPkts) {
    logLine("LORA_ERR", String("Invalid packet index ") + String(pktIdx) + " >= " + String(v.totalPkts));
    return;
  }
  
  // Only store if we haven't received this packet yet
  if (v.chunks[pktIdx].empty()) {
    v.chunks[pktIdx].assign(payload, payload + payloadLen);
    v.receivedPkts++;
    logLine("LORA_RX", String("VC pkt ") + String(pktIdx + 1) + "/" + String(v.totalPkts) + " stored");
  } else {
    logLine("LORA_RX", String("VC pkt ") + String(pktIdx + 1) + "/" + String(v.totalPkts) + " duplicate");
  }
  v.lastActivity = millis();

  if (v.receivedPkts >= v.totalPkts) {
    logLine("LORA_RX", "All packets received — reassembling...");
    size_t totalBytes = 0;
    for (auto &c : v.chunks) totalBytes += c.size();
    logLine("LORA_RX", String("Reassembling ") + String(totalBytes) + " bytes from " + String(v.totalPkts) + " packets");
    std::vector<uint8_t> adpcm; adpcm.reserve(totalBytes);
    for (auto &c : v.chunks) adpcm.insert(adpcm.end(), c.begin(), c.end());

    IMAState st{0, 0};
    std::vector<int16_t> pcm;
    ADPCM::decode(adpcm.data(), adpcm.size(), pcm, st);
    logLine("ADPCM_DEC", String("Decoded ") + String(pcm.size()) + " samples");

    std::vector<uint8_t> pcmBytes;
    pcmBytes.reserve(pcm.size() * 2);
    for (auto s : pcm) {
      pcmBytes.push_back((uint8_t)(s & 0xFF));
      pcmBytes.push_back((uint8_t)((s >> 8) & 0xFF));
    }

    String b64 = b64Encode(pcmBytes.data(), pcmBytes.size());
    if (connected && BT.hasClient()) {
      DynamicJsonDocument out(8192);
      out["type"] = "voice_message";
      out["messageId"] = msgId;
      out["from_node"] = nodeId;
      out["sender"] = nodeId;  // Add alternative sender field
      out["data_b64_pcm16le"] = b64;  // Match Flutter app expected field name
      out["timestamp"] = String(millis());
      out["message"] = "Voice Message";  // Add message text for display
      String outS;
      serializeJson(out, outS);
      logLine("BT_TX", "Sending JSON: " + outS);
      BT.println(outS);
      logLine("BT_TX", "Voice message forwarded to app");
    }
    clearSession(idx);
  }

  unsigned long now = millis();
  for (int i = 0; i < MAX_VOICE_SESSIONS; i++)
    if (sessions[i].active && now - sessions[i].lastActivity > VOICE_TIMEOUT) {
      logLine("CLEANUP", (String("Drop expired session ") + sessions[i].msgId).c_str());
      clearSession(i);
    }
}

// ----------- SETUP -----------
void setup() {
  Serial.begin(115200);
  delay(50);

  uint64_t id = ESP.getEfuseMac();
  nodeId = "NODE_" + String((uint32_t)(id >> 32), HEX);
  nodeId.toUpperCase();

  logLine("BOOT", "Initializing ESP32 LoRa Voice Bridge...");
  SPI.begin(18, 19, 23, NSS);
  LoRa.setPins(NSS, RST, DIO0);
  if (!LoRa.begin(FREQ)) {
    logLine("ERROR", "LoRa init failed — check wiring/freq");
    while (1) delay(1000);
  }
  LoRa.setTxPower(17);
  LoRa.setSpreadingFactor(9);
  LoRa.setSignalBandwidth(125E3);
  LoRa.enableCrc();
  logLine("LORA_INIT", "SX1278 ready");

  BT.begin(BT_DEVICE_NAME);
  logLine("BT_INIT", String("Bluetooth started: ") + BT_DEVICE_NAME);
  logLine("READY", String("Node ID: ") + nodeId);
}

// ----------- LOOP -----------
void loop() {
  if (BT.hasClient()) {
    if (!connected) connected = true;
    while (BT.available()) {
      char c = (char)BT.read();
      if (c == '\n' || c == '\r') {
        if (btBuf.length()) { handleBT(btBuf); btBuf = ""; }
      } else {
        if (btBuf.length() < 1024) btBuf += c;
        else btBuf = "";
      }
    }
  } else connected = false;

  processLoRa();
  delay(5);
}