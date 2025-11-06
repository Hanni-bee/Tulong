/*
 * ESP32 NRF24L01 + Bluetooth (SPP) + ADPCM Voice Bridge - V2 Protocol
 * Compatible with Flutter App PTT system
 * 
 * Node Roles:
 *   Node A → "ESP32_Node_A"
 *   Node B → "ESP32_Node_B"
 *   Node C → "ESP32_Node_C"
 *
 * NRF24L01 Wiring:
 *   CE   = GPIO 4
 *   CSN  = GPIO 5
 *   MOSI = GPIO 23
 *   MISO = GPIO 19
 *   SCK  = GPIO 18
 *   IRQ  = GPIO 2 (optional)
 *
 * NRF24L01 @ 2.4 GHz
 */

#include <Arduino.h>
#include <BluetoothSerial.h>
#include <SPI.h>
#include <nRF24L01.h>
#include <RF24.h>
#include <ArduinoJson.h>
#include <vector>

// ✅ Base64 support (ESP32 core 3.x)
extern "C" {
  #include "libb64/cdecode.h"
  #include "libb64/cencode.h"
}

// ===== VoiceProtoV2 Protocol Definitions =====
enum : uint8_t { VP2_START = 0xE0, VP2_DATA = 0xE1, VP2_END = 0xE2 };

// 5-byte packed header → payload ≤ 27B for a 32B RF packet
struct __attribute__((packed)) V2Hdr {
  uint8_t  type;     // VP2_*
  uint16_t seqLE;    // little-endian
  uint8_t  len;      // payload bytes (0..27)
  uint8_t  crc8;     // CRC-8 over [type|seq|len|payload], excl. crc8 byte
};

// CRC-8 (poly 0x07, init 0x00), no reflect, no xorout
static inline uint8_t crc8_update(uint8_t crc, const uint8_t* p, size_t n) {
  while (n--) {
    crc ^= *p++;
    for (uint8_t b = 0; b < 8; b++)
      crc = (crc & 0x80) ? (uint8_t)((crc << 1) ^ 0x07) : (uint8_t)(crc << 1);
  }
  return crc;
}

static inline uint8_t crc8_calc(const void* data, size_t n) {
  return crc8_update(0x00, (const uint8_t*)data, n);
}

#ifndef VP2_MAX_PAYLOAD
#define VP2_MAX_PAYLOAD 27   // nRF24-friendly
#endif

// ---------------- CONFIG ----------------
#define CE_PIN 4
#define CSN_PIN 5
#define RF24_CHANNEL 76  // 2.476 GHz
#define BT_DEVICE_NAME "ESP32_Node_B"  // change per node

// NRF24L01 addresses (5 bytes)
const uint64_t address[2] = {0xF0F0F0F0E1LL, 0xF0F0F0F0E2LL};  // Node A=0, Node B=1
const int thisNode = 1;  // Node B uses address[1]

RF24 radio(CE_PIN, CSN_PIN);
BluetoothSerial BT;
String nodeId = "";
String btBuf = "";
bool connected = false;

// Voice reassembly buffer for V2 protocol
std::vector<uint8_t> vp2_audio_buffer;
bool vp2_voice_open = false;
uint16_t vp2_expect = 0;

// ---------- LOGGING UTILITY ----------
void logLine(const char* tag, const String &msg) {
  unsigned long ms = millis();
  Serial.printf("[%08lu] %-10s %s\n", ms, tag, msg.c_str());
}

// ---------------- UTILITIES -------------
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

// ===== nRF24 write/read helpers =====
static bool rfWrite(const uint8_t* buf, uint8_t n) {
  if (n == 0 || n > 32) return false;
  radio.stopListening();
  bool ok = false;
  for (int attempt = 0; attempt < 3 && !ok; attempt++) {
    ok = radio.write(buf, n);
    if (!ok) delay(5);
  }
  radio.startListening();
  return ok;
}

static bool rfRead(uint8_t* raw, uint8_t* len) {
  if (!radio.available()) return false;
  uint8_t n = radio.getDynamicPayloadSize();
  if (n == 0 || n > 32) { radio.flush_rx(); return false; }
  radio.read(raw, n);
  *len = n;
  return true;
}

// ===== TX: V2 send helpers =====
static uint16_t g_txSeq = 0;

static bool vp2_send_control(uint8_t type) {
  V2Hdr h;
  h.type = type;
  h.seqLE = (type == VP2_START ? 0 : g_txSeq++);
  h.len = 0;
  h.crc8 = crc8_calc(&h, 4);  // header (type|seq|len), no payload
  return rfWrite((uint8_t*)&h, sizeof(V2Hdr));
}

static bool vp2_send_start() {
  g_txSeq = 0;
  return vp2_send_control(VP2_START);
}

static bool vp2_send_end() {
  return vp2_send_control(VP2_END);
}

static bool vp2_send_audio(const uint8_t* data, size_t n) {
  size_t i = 0;
  while (i < n) {
    const uint8_t L = (uint8_t)min((size_t)VP2_MAX_PAYLOAD, n - i);
    uint8_t buf[sizeof(V2Hdr) + VP2_MAX_PAYLOAD];
    V2Hdr* h = (V2Hdr*)buf;
    h->type = VP2_DATA;
    h->seqLE = g_txSeq++;
    h->len = L;
    memcpy(buf + sizeof(V2Hdr), data + i, L);
    
    uint8_t crc = 0;
    crc = crc8_update(crc, (uint8_t*)h, 4);              // type|seq|len
    crc = crc8_update(crc, buf + sizeof(V2Hdr), L);      // payload
    h->crc8 = crc;
    
    if (!rfWrite(buf, (uint8_t)(sizeof(V2Hdr) + L))) return false;
    i += L;
    delay(2);  // pacing
  }
  return true;
}

// ===== RX: V2 parsing =====
static void vp2_handle_one(const uint8_t* raw, uint8_t rfLen) {
  if (rfLen < sizeof(V2Hdr)) return;
  
  const V2Hdr* h = (const V2Hdr*)raw;
  const uint8_t payLen = (uint8_t)(rfLen - sizeof(V2Hdr));
  
  if (payLen != h->len || payLen > VP2_MAX_PAYLOAD) {
    logLine("V2_LEN_ERR", String("Expected ") + h->len + " got " + payLen);
    return;
  }
  
  uint8_t crc = 0;
  crc = crc8_update(crc, raw, 4);
  crc = crc8_update(crc, raw + sizeof(V2Hdr), payLen);
  
  if (crc != h->crc8) {
    logLine("V2_CRC_ERR", String("CRC mismatch"));
    return;
  }
  
  switch (h->type) {
    case VP2_START:
      vp2_voice_open = true;
      vp2_expect = 0;
      vp2_audio_buffer.clear();
      logLine("V2_RX", "START");
      if (connected && BT.hasClient()) BT.println("<VOICE_START>");
      return;
      
    case VP2_END:
      if (vp2_voice_open) {
        vp2_voice_open = false;
        logLine("V2_RX", "END");
        
        // Decode and forward to phone
        if (vp2_audio_buffer.size() > 0) {
          IMAState st{0, 0};
          std::vector<int16_t> pcm;
          ADPCM::decode(vp2_audio_buffer.data(), vp2_audio_buffer.size(), pcm, st);
          
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
            out["from_node"] = nodeId;
            out["data_b64_pcm16le"] = b64;
            String outS;
            serializeJson(out, outS);
            BT.println(outS);
          }
          vp2_audio_buffer.clear();
        }
        
        if (connected && BT.hasClient()) BT.println("<VOICE_END>");
      }
      return;
      
    case VP2_DATA: {
      if (!vp2_voice_open) {
        logLine("V2_ERR", "DATA_WHEN_CLOSED");
        return;
      }
      
      const uint16_t seq = h->seqLE;
      if (seq != vp2_expect) {
        logLine("V2_SEQ", String("Loss expect=") + vp2_expect + " got=" + seq);
        vp2_expect = (uint16_t)(seq + 1);
      } else {
        vp2_expect++;
      }
      
      // Accumulate audio payload
      const uint8_t* p = raw + sizeof(V2Hdr);
      const uint8_t L = payLen;
      vp2_audio_buffer.insert(vp2_audio_buffer.end(), p, p + L);
      
      return;
    }
  }
}

void handleNRF24() {
  uint8_t raw[32], n;
  while (rfRead(raw, &n)) {
    vp2_handle_one(raw, n);
  }
}

// ----------- HANDLE BLUETOOTH MESSAGES ----------
static void handleBT(const String &msg) {
  // Check for V2 protocol markers
  if (msg == "<VOICE_START>") {
    logLine("BT_RX", "Voice START marker");
    vp2_send_start();
    return;
  }
  
  if (msg == "<VOICE_END>") {
    logLine("BT_RX", "Voice END marker");
    vp2_send_end();
    return;
  }
  
  // Check for voice frame with base64 data
  if (msg.indexOf("\"pcm16leb64\"") > 0 || msg.indexOf("\"voice_frame\"") > 0) {
    logLine("BT_RX", "Voice frame received from app");
    
    DynamicJsonDocument doc(4096);
    if (deserializeJson(doc, msg)) {
      logLine("JSON_ERR", "Failed to parse incoming JSON");
      return;
    }
    
    String b64 = doc["pcm16leb64"] | "";
    if (b64.isEmpty()) {
      logLine("BT_WARN", "Empty audio frame");
      return;
    }
    
    // Decode base64 → PCM → ADPCM
    std::vector<uint8_t> pcmBytes = b64Decode(b64);
    std::vector<int16_t> pcm;
    pcm.reserve(pcmBytes.size() / 2);
    for (size_t i = 0; i + 1 < pcmBytes.size(); i += 2)
      pcm.push_back((int16_t)((uint8_t)pcmBytes[i] | ((uint8_t)pcmBytes[i + 1] << 8)));
    
    IMAState st{0, 0};
    std::vector<uint8_t> adpcm;
    ADPCM::encode(pcm.data(), pcm.size(), adpcm, st);
    logLine("ADPCM_ENC", String("PCM→ADPCM OK (") + String(adpcm.size()) + " bytes)");
    
    // Send via V2 protocol
    if (!vp2_send_start()) {
      logLine("V2_ERR", "Failed to send START");
      return;
    }
    delay(10);
    
    if (!vp2_send_audio(adpcm.data(), adpcm.size())) {
      logLine("V2_ERR", "Failed to send audio");
      return;
    }
    
    if (!vp2_send_end()) {
      logLine("V2_ERR", "Failed to send END");
      return;
    }
    
    if (BT.hasClient()) BT.println("{\"ack\":\"voice_sent\"}");
    return;
  }
  
  // Text messages (unchanged)
  if (msg.indexOf("\"message\":") > 0) {
    logLine("BT_RX", "Text message received");
    // Text messages can still use simple NRF24 write (not V2 protocol)
    String out = msg;
    if (out.lastIndexOf('}') > 0) {
      out = out.substring(0, out.lastIndexOf('}')) + ",\"from_node\":\"" + nodeId + "\"}";
    }
    
    // Send text via NRF24 (simple mode, not V2)
    radio.stopListening();
    radio.write(out.c_str(), min((size_t)32, out.length()));
    radio.startListening();
    
    if (BT.hasClient()) BT.println("{\"ack\":\"text_sent\"}");
    logLine("NRF_TX", "Text message sent");
  }
}

// ----------- SETUP -----------
void setup() {
  Serial.begin(115200);
  delay(50);
  
  uint64_t id = ESP.getEfuseMac();
  nodeId = "NODE_" + String((uint32_t)(id >> 32), HEX);
  nodeId.toUpperCase();
  
  logLine("BOOT", "Initializing ESP32 NRF24L01 Voice Bridge V2...");
  
  // Initialize SPI for NRF24L01
  SPI.begin(18, 19, 23, CSN_PIN);  // SCK, MISO, MOSI, CSN
  
  // Initialize NRF24L01
  if (!radio.begin()) {
    logLine("ERROR", "NRF24L01 init failed — check wiring");
    while(1) delay(1000);
  }
  
  // Configure NRF24L01
  radio.setChannel(RF24_CHANNEL);
  radio.setPALevel(RF24_PA_HIGH);
  radio.setDataRate(RF24_1MBPS);
  radio.setAutoAck(true);
  radio.setRetries(10, 15);
  radio.setCRCLength(RF24_CRC_16);
  radio.enableDynamicPayloads();
  radio.enableAckPayload();
  
  // Set addresses (Node B listens on address[1], sends to address[0])
  radio.openReadingPipe(0, address[thisNode]);
  radio.openWritingPipe(address[1 - thisNode]);  // Send to Node A
  radio.startListening();
  
  logLine("NRF_INIT", "NRF24L01 ready");
  
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
        if (btBuf.length()) {
          handleBT(btBuf);
          btBuf = "";
        }
      } else {
        if (btBuf.length() < 1024) btBuf += c;
        else btBuf = "";
      }
    }
  } else connected = false;
  
  handleNRF24();
  delay(5);
}
