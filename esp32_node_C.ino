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

// ✅ Base64 support (ESP32 core 3.x) — use libb64 block API
extern "C" {
  #include "libb64/cdecode.h"
  #include "libb64/cencode.h"
}

// ---------------- CONFIG ----------------
#define NSS 5
#define RST 2
#define DIO0 4
#define FREQ 433E6
#define BT_DEVICE_NAME "ESP32_Node_C"  // change per node

BluetoothSerial BT;
String nodeId = "";
String btBuf = "";
bool connected = false;

// ---------------- UTILITIES -------------
static uint16_t crc16(const uint8_t *buf, size_t len) {
  uint16_t crc = 0xFFFF;
  while (len--) {
    crc ^= *buf++;
    for (int i = 0; i < 8; ++i) crc = (crc & 1) ? (crc >> 1) ^ 0xA001 : (crc >> 1);
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

// ----------- Base64 helpers (libb64) -------------
static std::vector<uint8_t> b64Decode(const String &in) {
  // max decoded length is ~ 3/4 of input; allocate safely
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
  // encoded length is ~ 4/3 of input + padding/newlines margin
  size_t outCap = (len * 4) / 3 + 8;
  std::vector<char> out(outCap);

  base64_encodestate s;
  base64_init_encodestate(&s);
  int n = base64_encode_block((const char*)data, (int)len, out.data(), &s);
  n += base64_encode_blockend(out.data() + n, &s);

  return String(out.data()).substring(0, n);
}

// ----------- ADPCM class (prevents Arduino auto-prototypes) ------------
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
        if (st.prevSample > 32767) st.prevSample = 32767;
        if (st.prevSample < -32768) st.prevSample = -32768;

        st.index += indexTable[code];
        if (st.index < 0) st.index = 0;
        if (st.index > 88) st.index = 88;

        out.push_back(st.prevSample);
      }
    }
  }
};

// ----------- SEND VOICE VIA LORA ----------
static const int LORA_MAX_PAYLOAD = 220;

static void sendVoiceLoRa(const String &msgId, const std::vector<uint8_t> &adpcm) {
  uint16_t total = (adpcm.size() + LORA_MAX_PAYLOAD - 1) / LORA_MAX_PAYLOAD;
  for (uint16_t i = 0; i < total; i++) {
    size_t off = (size_t)i * LORA_MAX_PAYLOAD;
    size_t len = min((size_t)LORA_MAX_PAYLOAD, adpcm.size() - off);
    uint16_t c = crc16(&adpcm[off], len);

    LoRa.beginPacket();
    LoRa.print("VC");            // magic header
    LoRa.print(msgId);           // 8-char ID (ASCII)
    LoRa.write((uint8_t)i);      // packet index
    LoRa.write((uint8_t)total);  // total packets
    LoRa.write((uint8_t)(c >> 8));
    LoRa.write((uint8_t)(c & 0xFF));
    LoRa.write(&adpcm[off], len);
    LoRa.endPacket();
    delay(25);
  }
}

// ----------- HANDLE BLUETOOTH MESSAGES ----------
static void handleBT(const String &msg) {
  // Voice frame from app
  if (msg.indexOf("\"voice_frame\"") > 0 || msg.indexOf("\"pcm16le_b64\"") > 0) {
    DynamicJsonDocument doc(4096);
    if (deserializeJson(doc, msg)) return;

    String mid = doc["messageId"] | makeMsgId();
    String b64 = doc["pcm16le_b64"] | "";
    if (b64.isEmpty()) return;

    // base64 -> PCM bytes
    std::vector<uint8_t> pcmBytes = b64Decode(b64);

    // bytes -> samples
    std::vector<int16_t> pcm;
    pcm.reserve(pcmBytes.size() / 2);
    for (size_t i = 0; i + 1 < pcmBytes.size(); i += 2) {
      int16_t s = (int16_t)((uint8_t)pcmBytes[i] | ((uint8_t)pcmBytes[i + 1] << 8));
      pcm.push_back(s);
    }

    // PCM -> ADPCM
    IMAState st{0, 0};
    std::vector<uint8_t> adpcm;
    ADPCM::encode(pcm.data(), pcm.size(), adpcm, st);

    // send over LoRa
    sendVoiceLoRa(mid, adpcm);
    if (BT.hasClient()) BT.println("{\"ack\":\"voice_sent\"}");

    Serial.printf("[VOICE] PCM %uB -> ADPCM %uB, msgId=%s\n",
                  (unsigned)(pcm.size() * 2), (unsigned)adpcm.size(), mid.c_str());
    return;
  }

  // Text message passthrough
  if (msg.indexOf("\"message\":") > 0) {
    int end = msg.lastIndexOf('}');
    String out = (end > 0) ? (msg.substring(0, end) + ",\"from_node\":\"" + nodeId + "\"}") : msg;

    LoRa.beginPacket();
    LoRa.print(out);
    LoRa.endPacket();

    if (BT.hasClient()) BT.println("{\"ack\":\"text_sent\"}");
    Serial.println("[TEXT] Sent via LoRa");
    return;
  }
}

// ----------- PROCESS LORA PACKETS -----------
static void processLoRa() {
  int sz = LoRa.parsePacket();
  if (!sz) return;

  String msg = "";
  while (LoRa.available()) msg += (char)LoRa.read();

  if (msg.startsWith("VC")) {
    // Binary/ADPCM voice frame — reassembly not implemented in this minimal build.
    Serial.println("[LoRa] Voice ADPCM chunk received");
  } else {
    // JSON text
    if (msg.indexOf(nodeId) > 0) return;  // skip own
    if (connected && BT.hasClient()) BT.println(msg);
    Serial.println("[LoRa] Text relayed to Bluetooth");
  }
}

// ----------- SETUP -----------
void setup() {
  Serial.begin(115200);
  delay(50);

  uint64_t id = ESP.getEfuseMac();
  nodeId = "NODE_" + String((uint32_t)(id >> 32), HEX);
  nodeId.toUpperCase();

  SPI.begin(18, 19, 23, NSS);      // SCK, MISO, MOSI, SS
  LoRa.setPins(NSS, RST, DIO0);
  if (!LoRa.begin(FREQ)) {
    Serial.println("LoRa init failed!");
    while (1) { delay(1000); }
  }
  LoRa.setTxPower(17);
  LoRa.setSpreadingFactor(9);
  LoRa.setSignalBandwidth(125E3);
  LoRa.enableCrc();

  BT.begin(BT_DEVICE_NAME);
  Serial.printf("[READY] %s (%s) initialized\n", BT_DEVICE_NAME, nodeId.c_str());
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
        else btBuf = ""; // overflow guard
      }
    }
  } else {
    connected = false;
  }

  processLoRa();
  delay(5);
}
