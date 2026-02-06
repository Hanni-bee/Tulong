/*
 * ESP32 nRF24L01 + Bluetooth SPP Voice Bridge (Node A / Node B)
 *
 * VOICE-SAFE + PROFILE/SOS META (severity + timestamp_ms)
 * - Adds severity + timestamp_ms for profile and SOS into ESP32 flash (Preferences/NVS)
 * - Includes severity + timestamp_ms in profile_response JSON (local + RF)
 * - Voice lock: while VOICE active (TX or RX), queue BT get_profile and ignore RF profile traffic
 * - Priority BT parse: VOICE markers -> VOICE chunks -> JSON commands -> chat framing
 *
 * JSON additions:
 *  sync_profile:
 *   {"command":"sync_profile", ... , "severity":"<string>", "timestamp_ms":<int>}
 *  sync_sos:
 *   {"command":"sync_sos", "message":"...", "severity":"<string>", "timestamp_ms":<int>}
 *
 * Notes:
 * - timestamp_ms recommended: Unix epoch ms (from app). ESP32 stores as int64.
 */

#include <SPI.h>
#include <nRF24L01.h>
#include <RF24.h>
#include "BluetoothSerial.h"
#include <Preferences.h>
#include <ArduinoJson.h>

// ----------------- Pins / Config -----------------
#define CE_PIN         26
#define CSN_PIN        27

// Change per node to avoid phone connecting to wrong ESP32
#define BT_DEVICE_NAME "ESP32_NodeA_VoiceAC"   // NodeB example: "ESP32_NodeB_VoiceAC"

// SOS tactile button (active LOW)
#define SOS_BTN_PIN    4

RF24 radio(CE_PIN, CSN_PIN);
BluetoothSerial SerialBT;
Preferences flashStorage;

// 5-byte addresses (pipe names). index 0 = Node A, index 1 = Node B.
const byte address[][6] = {"1Node", "2Node"};

// nRF settings
#define RF_CHANNEL     108
#define RF_DATARATE    RF24_250KBPS
#define RF_PALEVEL     RF24_PA_LOW

// ----------------- Packet header -----------------
enum : uint8_t { VTYPE_START = 0xD0, VTYPE_DATA = 0xD1, VTYPE_END = 0xD2 };
enum : uint8_t { TTYPE_TEXT  = 0xA0 };
enum : uint8_t { PTYPE_REQ   = 0xB0, PTYPE_RESP = 0xB1 }; // profile req/resp

struct __attribute__((packed)) VoiceHdr {
  uint8_t  type;
  uint16_t seq;    // little-endian
  uint8_t  crc8;   // CRC-8 over [type|seq(2)|payload] (crc8 excluded)
};

// ----------------- State (Voice) -----------------
bool     isVoice = false;      // local TX voice mode (from phone)
uint16_t g_txSeq = 0;

bool     rxVoice = false;      // receiving voice from RF
uint16_t rxExpect = 0;

bool     txVoice = false;      // transmitting voice to RF
unsigned long txLastEnd = 0;

unsigned long lastRxMillis = 0;
const unsigned long VOICE_TIMEOUT = 3000;

// ----------------- State (Text reassembly) -----------------
bool     rxText = false;
uint16_t textExpect = 0;
String   textBuffer = "";
unsigned long lastTextPacketTime = 0;
const unsigned long TEXT_TIMEOUT_MS = 900;

// ----------------- State (Profile RESP reassembly) -----------------
bool     rxProf = false;
uint16_t profExpect = 0;
String   profBuffer = "";
unsigned long lastProfPacketTime = 0;
const unsigned long PROF_TIMEOUT_MS = 1200;

// ----------------- State (Profile REQ reassembly) -----------------
bool     rxReq = false;
uint16_t reqExpect = 0;
String   reqBuffer = "";
unsigned long lastReqPacketTime = 0;
const unsigned long REQ_TIMEOUT_MS = 350;

// ----------------- SOS button debounce -----------------
bool lastBtnState = HIGH;
unsigned long lastBtnChange = 0;
const unsigned long BTN_DEBOUNCE_MS = 40;
bool sosFired = false;

// ----------------- Profile request tracking -----------------
String g_lastProfReqId = "";
String g_lastProfTargetUid = "";

// ----------------- NEW: queued get_profile while voice is active -----------------
bool   g_profileQueued = false;
String g_queuedTargetUid = "";
bool   g_queuedForceRf = false;

// ----------------- Helpers -----------------
static inline bool voiceActive() {
  return (isVoice || txVoice || rxVoice);
}

// read string safely
static inline String readFlashString(const char* key, const String& def = "") {
  flashStorage.begin("tulong", true);
  String v = flashStorage.getString(key, def.c_str());
  flashStorage.end();
  v.trim();
  return v;
}

// read int64 safely (Preferences stores long long)
static inline int64_t readFlashI64(const char* key, int64_t def = 0) {
  flashStorage.begin("tulong", true);
  int64_t v = (int64_t)flashStorage.getLong64(key, def);
  flashStorage.end();
  return v;
}

static inline String myUidOrUnknown() {
  String u = readFlashString("profile_uid", "");
  if (u.length() == 0 || u == "(not set)") u = "UNKNOWN";
  return u;
}

String jsonEscapeBasic(String s) {
  s.replace("\\", "\\\\");
  s.replace("\"", "'");
  s.replace("\n", " ");
  s.replace("\r", " ");
  return s;
}

// ----------------- CRC8 (poly 0x07, init 0x00; MSB-first) -----------------
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

uint8_t crc8_hdr_payload(uint8_t type, uint16_t seq, const uint8_t* payload, uint8_t payLen) {
  uint8_t head3[3];
  head3[0] = type;
  head3[1] = (uint8_t)(seq & 0xFF);
  head3[2] = (uint8_t)((seq >> 8) & 0xFF);

  uint8_t crc = crc8_calc(head3, 3);
  if (payLen > 0 && payload != nullptr) {
    for (uint8_t i = 0; i < payLen; i++) {
      crc ^= payload[i];
      for (uint8_t b = 0; b < 8; b++) {
        if (crc & 0x80) crc = (crc << 1) ^ 0x07;
        else            crc <<= 1;
      }
    }
  }
  return crc;
}

// ----------------- nRF helpers -----------------
bool sendRfRaw(const void* buf, uint8_t len) {
  if (len == 0 || len > 32) return false;

  radio.stopListening();

  if (radio.write(buf, len)) {
    radio.startListening();
    delay(5);
    return true;
  }

  // long retry window (ok for text/profile, not ideal for realtime)
  unsigned long start = millis();
  while (millis() - start < 7000) {
    if (radio.write(buf, len)) {
      radio.startListening();
      delay(5);
      return true;
    }
    delay(40);
  }

  radio.stopListening();
  radio.flush_tx();
  radio.flush_rx();
  radio.clearStatusFlags();
  delay(5);
  radio.startListening();
  return false;
}

// voice-fast write (no long stall)
bool sendRfRawVoiceFast(const void* buf, uint8_t len) {
  if (len == 0 || len > 32) return false;
  radio.stopListening();
  bool ok = radio.write(buf, len);
  radio.startListening();
  return ok;
}

bool channelBusy() {
  if (radio.testCarrier()) return true;
  if (rxVoice) return true;
  if (millis() - txLastEnd < 300) return true;
  return false;
}

// ----------------- Voice TX -----------------
bool sendVoiceControl(uint8_t type) {
  uint8_t buf[sizeof(VoiceHdr)] = {0};
  VoiceHdr* hdr = (VoiceHdr*)buf;
  hdr->type = type;
  hdr->seq  = 0;
  hdr->crc8 = crc8_hdr_payload(hdr->type, hdr->seq, nullptr, 0);

  const bool ok = sendRfRaw(buf, sizeof(VoiceHdr));
  Serial.println(String("[RF_VOICE_TX] ") + (type == VTYPE_START ? "START" : "END") + (ok ? " OK" : " FAIL"));
  return ok;
}

bool sendVoiceLineWithSeq(const String& base64Line) {
  const int N = base64Line.length();
  int i = 0;

  while (i < N) {
    const uint8_t L = (uint8_t)min(28, N - i);

    uint8_t buf[sizeof(VoiceHdr) + 28] = {0};
    VoiceHdr* hdr = (VoiceHdr*)buf;
    hdr->type = VTYPE_DATA;
    hdr->seq  = g_txSeq;

    memcpy(buf + sizeof(VoiceHdr), base64Line.c_str() + i, L);
    hdr->crc8 = crc8_hdr_payload(hdr->type, hdr->seq, buf + sizeof(VoiceHdr), L);

    // For voice, drop instead of stalling (prevents "voice freeze")
    const bool ok = sendRfRawVoiceFast(buf, sizeof(VoiceHdr) + L);
    if (!ok) {
      Serial.println(String("[RF_VOICE_TX_DROP] seq=") + g_txSeq);
    }

    g_txSeq++;
    i += L;
    delay(4);
  }
  return true;
}

// ----------------- Chunk sender utility -----------------
uint16_t sendStringPacketSeqBase(uint8_t type, const String &msg, uint16_t seqBase) {
  const int N = msg.length();
  for (int i = 0; i < N; i += 28) {
    const uint8_t L = (uint8_t)min(28, N - i);

    uint8_t buf[sizeof(VoiceHdr) + 28] = {0};
    VoiceHdr *hdr = (VoiceHdr*)buf;
    hdr->type = type;
    hdr->seq  = seqBase;

    memcpy(buf + sizeof(VoiceHdr), msg.c_str() + i, L);
    hdr->crc8 = crc8_hdr_payload(hdr->type, hdr->seq, buf + sizeof(VoiceHdr), L);

    if (!sendRfRaw(buf, sizeof(VoiceHdr) + L)) {
      Serial.println(String("[RF_TX_ERR] type=") + type + " fail seq=" + hdr->seq);
      return seqBase;
    }

    seqBase++;
    delay(2);
  }
  return seqBase;
}

// ----------------- SOS framed TX (RF) -----------------
void sendSosFramedFromFlash() {
  if (voiceActive()) {
    Serial.println("[SOS_BTN] blocked during voice");
    return;
  }

  String uid = myUidOrUnknown();

  String sos = readFlashString("sos_msg", "");
  if (sos.length() == 0 || sos == "(not set)") {
    Serial.println("[SOS_BTN] No sos_msg in flash. Not sending.");
    return;
  }

  String sev = readFlashString("sos_sev", "UNKNOWN");
  int64_t ts = readFlashI64("sos_ts_ms", 0);

  // Keep header compatible with your existing flow:
  // <MSG_START:UIDSOS> ... <MSG_END>
  // Put meta inside body (so app can parse later without breaking old framing)
  String start = String("<MSG_START:") + uid + "SOS>";
  String end   = "<MSG_END>";

  String meta = String("[SOS_META] severity=") + sev + " timestamp_ms=" + String((long long)ts);
  String body = meta + "\n" + sos;

  Serial.println("[SOS_BTN] Sending SOS framed...");
  uint16_t seq = 0;
  seq = sendStringPacketSeqBase(TTYPE_TEXT, start, seq);
  delay(15);
  seq = sendStringPacketSeqBase(TTYPE_TEXT, body, seq);
  delay(15);
  seq = sendStringPacketSeqBase(TTYPE_TEXT, end, seq);

  Serial.println(String("[SOS_BTN] Sent. nextSeq=") + seq);
}

// ----------------- Profile RF protocol -----------------
static inline String makeReqId() {
  uint32_t m = millis();
  uint16_t r = (uint16_t)(esp_random() & 0xFFFF);
  char buf[24];
  snprintf(buf, sizeof(buf), "%lu_%u", (unsigned long)m, (unsigned)r);
  return String(buf);
}

bool rfSendProfileReq(const String& destUid, const String& targetUid) {
  String reqId = makeReqId();
  String payload = String("REQ|") + reqId + "|" + destUid + "|" + targetUid;

  g_lastProfReqId = reqId;
  g_lastProfTargetUid = targetUid;

  Serial.println(String("[RF_PROF_REQ_TX] reqId=") + reqId + " destUid=" + destUid +
                 " targetUid=" + targetUid + " bytes=" + payload.length());

  uint16_t seq = 0;
  sendStringPacketSeqBase(PTYPE_REQ, payload, seq);
  return true;
}

bool rfSendProfileResp(const String& reqId, const String& destUid) {
  flashStorage.begin("tulong", true);
  String uid      = flashStorage.getString("profile_uid", "");
  String name     = flashStorage.getString("profile_name", "");
  String username = flashStorage.getString("p_user", "");
  String street   = flashStorage.getString("profile_street", "");
  String province = flashStorage.getString("p_prov", "");
  String city     = flashStorage.getString("profile_city", "");
  String barangay = flashStorage.getString("p_brgy", "");
  String suffix   = flashStorage.getString("profile_suffix", "");
  String severity = flashStorage.getString("profile_sev", "UNKNOWN");
  int64_t ts_ms   = (int64_t)flashStorage.getLong64("profile_ts_ms", 0);
  flashStorage.end();

  uid.trim(); name.trim(); username.trim(); street.trim(); province.trim();
  city.trim(); barangay.trim(); suffix.trim(); severity.trim();

  // JSON includes severity + timestamp_ms
  String j = "{";
  j += "\"uid\":\"" + jsonEscapeBasic(uid) + "\",";
  j += "\"name\":\"" + jsonEscapeBasic(name) + "\",";
  j += "\"username\":\"" + jsonEscapeBasic(username) + "\",";
  j += "\"street\":\"" + jsonEscapeBasic(street) + "\",";
  j += "\"province\":\"" + jsonEscapeBasic(province) + "\",";
  j += "\"city\":\"" + jsonEscapeBasic(city) + "\",";
  j += "\"barangay\":\"" + jsonEscapeBasic(barangay) + "\",";
  j += "\"suffix\":\"" + jsonEscapeBasic(suffix) + "\",";
  j += "\"severity\":\"" + jsonEscapeBasic(severity) + "\",";
  j += "\"timestamp_ms\":" + String((long long)ts_ms);
  j += "}";

  String payload = String("RSP|") + reqId + "|" + destUid + "|" + j;

  Serial.println(String("[RF_PROF_RESP_TX] reqId=") + reqId + " -> destUid=" + destUid + " bytes=" + payload.length());

  uint16_t seq = 0;
  seq = sendStringPacketSeqBase(PTYPE_RESP, payload, seq);

  Serial.println(String("[RF_PROF_RESP_TX] sent chunks, nextSeq=") + seq);
  return true;
}

// ----------------- Flash save functions -----------------
void saveProfileToFlash(String name, String username, String street, String province,
                        String city, String barangay, String uid, String suffix,
                        String severity, int64_t timestamp_ms) {

  if (!flashStorage.begin("tulong", false)) {
    Serial.println("[FLASH_ERR] begin() failed");
    return;
  }

  flashStorage.putString("profile_name", name);
  flashStorage.putString("p_user", username);
  flashStorage.putString("profile_street", street);
  flashStorage.putString("p_prov", province);
  flashStorage.putString("profile_city", city);
  flashStorage.putString("p_brgy", barangay);
  flashStorage.putString("profile_uid", uid);
  flashStorage.putString("profile_suffix", suffix);

  // NEW:
  flashStorage.putString("profile_sev", severity);
  flashStorage.putLong64("profile_ts_ms", (long long)timestamp_ms);

  int count = flashStorage.getInt("p_cnt", 0) + 1;
  flashStorage.putInt("p_cnt", count);

  flashStorage.end();

  Serial.println("[FLASH] Profile saved OK.");
  Serial.println(String("[FLASH] p_cnt=") + count);
  Serial.println(String("[FLASH] profile_sev=") + severity + " ts_ms=" + String((long long)timestamp_ms));
}

void saveSosToFlash(String message, String severity, int64_t timestamp_ms) {
  if (!flashStorage.begin("tulong", false)) {
    Serial.println("[FLASH_ERR] begin() failed");
    return;
  }

  flashStorage.putString("sos_msg", message);

  // NEW:
  flashStorage.putString("sos_sev", severity);
  flashStorage.putLong64("sos_ts_ms", (long long)timestamp_ms);

  int count = flashStorage.getInt("s_cnt", 0) + 1;
  flashStorage.putInt("s_cnt", count);
  flashStorage.end();

  Serial.println(String("[FLASH] SOS saved OK. s_cnt=") + count);
  Serial.println(String("[FLASH] sos_sev=") + severity + " ts_ms=" + String((long long)timestamp_ms));
}

// ----------------- BT JSON parsing -----------------
bool parseBtJson(const String& msg, JsonDocument& doc) {
  DeserializationError err = deserializeJson(doc, msg);
  if (err) {
    Serial.print("[BT_JSON_ERR] ");
    Serial.println(err.c_str());
    return false;
  }
  return true;
}

// ----------------- Profile queue processing -----------------
void processQueuedProfileReqIfAny() {
  if (!g_profileQueued) return;
  if (voiceActive()) return;

  String targetUid = g_queuedTargetUid;
  bool forceRf = g_queuedForceRf;

  g_profileQueued = false;
  g_queuedTargetUid = "";
  g_queuedForceRf = false;

  String myUid = myUidOrUnknown();
  Serial.println(String("[PROFILE_QUEUE] processing targetUid=") + targetUid + " force_rf=" + (forceRf ? "true" : "false"));

  if (targetUid.length() == 0) return;

  // process as RF request (safe after voice)
  rfSendProfileReq(myUid, targetUid);
}

// ----------------- BT Command Handler -----------------
void handleSyncCommand(const String& msg) {
  StaticJsonDocument<1024> doc;
  if (!parseBtJson(msg, doc)) return;

  String command = String((const char*)(doc["command"] | ""));

  if (command == "sync_profile") {
    String name     = String((const char*)(doc["name"]     | ""));
    String username = String((const char*)(doc["username"] | ""));
    String street   = String((const char*)(doc["street"]   | ""));
    String province = String((const char*)(doc["province"] | ""));
    String city     = String((const char*)(doc["city"]     | ""));
    String barangay = String((const char*)(doc["barangay"] | ""));
    String uid      = String((const char*)(doc["uid"]      | ""));
    String suffix   = String((const char*)(doc["suffix"]   | ""));

    // NEW (backward compatible)
    String severity = String((const char*)(doc["severity"] | "UNKNOWN"));
    int64_t ts_ms = (int64_t)(doc["timestamp_ms"] | (long long)0);

    // if app doesn't send timestamp, store 0 (or you can store millis(), but that's not epoch)
    if (name.length() > 0 || username.length() > 0 || uid.length() > 0) {
      saveProfileToFlash(name, username, street, province, city, barangay, uid, suffix, severity, ts_ms);
    }

  } else if (command == "sync_sos") {
    String message  = String((const char*)(doc["message"] | ""));
    String severity = String((const char*)(doc["severity"] | "UNKNOWN"));
    int64_t ts_ms   = (int64_t)(doc["timestamp_ms"] | (long long)0);

    if (message.length() > 0) {
      saveSosToFlash(message, severity, ts_ms);
    }

  } else if (command == "get_profile") {
    String targetUid = String((const char*)(doc["target_uid"] | ""));
    if (targetUid.length() == 0) targetUid = String((const char*)(doc["uid"] | ""));
    targetUid.trim();

    bool forceRf = doc["force_rf"] | false;

    // VOICE LOCK: queue get_profile during voice
    if (voiceActive()) {
      g_profileQueued = true;
      g_queuedTargetUid = targetUid;
      g_queuedForceRf = forceRf;

      Serial.println(String("[BT_GET_PROFILE] queued during voice targetUid=") + targetUid);
      SerialBT.println("{\"command\":\"profile_queued\",\"reason\":\"voice_active\"}");
      return;
    }

    String myUid = myUidOrUnknown();

    // local match (unless forced)
    if (!forceRf && targetUid.length() > 0 && targetUid == myUid) {
      flashStorage.begin("tulong", true);
      String uid      = flashStorage.getString("profile_uid", "");
      String name     = flashStorage.getString("profile_name", "");
      String username = flashStorage.getString("p_user", "");
      String street   = flashStorage.getString("profile_street", "");
      String province = flashStorage.getString("p_prov", "");
      String city     = flashStorage.getString("profile_city", "");
      String barangay = flashStorage.getString("p_brgy", "");
      String suffix   = flashStorage.getString("profile_suffix", "");
      String severity = flashStorage.getString("profile_sev", "UNKNOWN");
      int64_t ts_ms   = (int64_t)flashStorage.getLong64("profile_ts_ms", 0);
      flashStorage.end();

      String response = String("{") +
        "\"command\":\"profile_response\"," +
        "\"data\":{" +
          "\"uid\":\"" + jsonEscapeBasic(uid) + "\"," +
          "\"name\":\"" + jsonEscapeBasic(name) + "\"," +
          "\"username\":\"" + jsonEscapeBasic(username) + "\"," +
          "\"street\":\"" + jsonEscapeBasic(street) + "\"," +
          "\"province\":\"" + jsonEscapeBasic(province) + "\"," +
          "\"city\":\"" + jsonEscapeBasic(city) + "\"," +
          "\"barangay\":\"" + jsonEscapeBasic(barangay) + "\"," +
          "\"suffix\":\"" + jsonEscapeBasic(suffix) + "\"," +
          "\"severity\":\"" + jsonEscapeBasic(severity) + "\"," +
          "\"timestamp_ms\":" + String((long long)ts_ms) +
        "}" +
      "}";

      SerialBT.println(response);
    } else {
      if (targetUid.length() > 0) {
        rfSendProfileReq(myUid, targetUid);
      }
    }
  }
}

// ----------------- RF receive handler -----------------
void handleRfPacket() {
  uint8_t len = radio.getDynamicPayloadSize();
  if (len == 0 || len > 32) { radio.flush_rx(); return; }

  uint8_t raw[32];
  radio.read(raw, len);
  lastRxMillis = millis();

  if (len < sizeof(VoiceHdr)) {
    String text((char*)raw, len);
    if (!rxVoice) SerialBT.println(text);
    return;
  }

  VoiceHdr* hdr = (VoiceHdr*)raw;
  const uint8_t payLen = (uint8_t)(len - sizeof(VoiceHdr));
  const uint8_t* payload = raw + sizeof(VoiceHdr);

  const uint8_t crcGot = hdr->crc8;
  const uint8_t crcExpect = crc8_hdr_payload(hdr->type, hdr->seq, payload, payLen);
  if (crcGot != crcExpect) {
    Serial.println("[RF_ERR] CRC mismatch, dropping packet");
    return;
  }

  // ----------------- VOICE RX -----------------
  if (hdr->type == VTYPE_START) {
    rxVoice = true; rxExpect = 0;
    Serial.println("[RF_VOICE_RX] START -> streaming to phone");

    if (txVoice) {
      txVoice = false; isVoice = false;
      SerialBT.println("<VOICE_DENY_BUSY>");
      return;
    }

    SerialBT.println("<VOICE_START>");
    return;
  }

  if (hdr->type == VTYPE_END) {
    rxVoice = false;
    Serial.println("[RF_VOICE_RX] END -> sending end marker to phone");
    SerialBT.println("<VOICE_END>");
    processQueuedProfileReqIfAny();
    return;
  }

  if (hdr->type == VTYPE_DATA) {
    if (!rxVoice) return;

    const uint16_t seq = hdr->seq;
    if (seq != rxExpect) {
      Serial.println(String("[RF_VOICE_RX_LOSS] got=") + seq + " expect=" + rxExpect);
      rxExpect = seq + 1;
    } else rxExpect++;

    SerialBT.write(payload, payLen);
    SerialBT.write('\n');
    return;
  }

  // VOICE LOCK: ignore profile traffic while voice is active
  if (voiceActive() && (hdr->type == PTYPE_REQ || hdr->type == PTYPE_RESP)) {
    return;
  }

  // ----------------- TEXT (chat) -----------------
  if (hdr->type == TTYPE_TEXT) {
    const uint16_t seq = hdr->seq;

    if (!rxText) {
      rxText = true;
      textBuffer = "";
      textExpect = seq + 1;
    }

    lastTextPacketTime = millis();

    if (seq != (uint16_t)(textExpect - 1)) {
      textExpect = seq + 2;
    } else {
      textExpect++;
    }

    textBuffer += String((char*)payload, payLen);
    return;
  }

  // ----------------- PROFILE REQ reassembly -----------------
  if (hdr->type == PTYPE_REQ) {
    String s((char*)payload, payLen);

    if (hdr->seq == 0) {
      rxReq = true;
      reqBuffer = "";
      reqExpect = 0;
    }
    if (!rxReq) return;

    lastReqPacketTime = millis();

    if (hdr->seq != reqExpect) reqExpect = hdr->seq;
    reqExpect++;

    reqBuffer += s;
    return;
  }

  // ----------------- PROFILE RESP reassembly -----------------
  if (hdr->type == PTYPE_RESP) {
    String s((char*)payload, payLen);

    if (!rxProf) {
      rxProf = true;
      profBuffer = "";
      profExpect = hdr->seq;
    }

    lastProfPacketTime = millis();

    if (hdr->seq != profExpect) profExpect = hdr->seq;
    profExpect++;

    profBuffer += s;
    return;
  }
}

// ----------------- Setup -----------------
void setup() {
  Serial.begin(115200);
  delay(300);

  SerialBT.begin(BT_DEVICE_NAME);
  delay(300);

  pinMode(SOS_BTN_PIN, INPUT_PULLUP);

  Serial.println("=== ESP32 Voice Bridge (VOICE-SAFE + SEV/TS) ===");
  Serial.println(String("[BT] Ready: ") + BT_DEVICE_NAME);

  if (!radio.begin()) {
    Serial.println("[RF] nRF24L01 init failed! Check wiring/power.");
    while (true) delay(1000);
  }

  radio.setAutoAck(true);
  radio.enableDynamicPayloads();
  radio.enableAckPayload();
  radio.setPALevel(RF_PALEVEL);
  radio.setDataRate(RF_DATARATE);
  radio.setChannel(RF_CHANNEL);
  radio.setRetries(5, 15);

  // =========================
  // RF PIPE CONFIG (IMPORTANT)
  // =========================
  // For Node A:
  //   openWritingPipe(address[1]);    // write to B
  //   openReadingPipe(1, address[0]); // read as A
  //
  // For Node B:
  //   openWritingPipe(address[0]);    // write to A
  //   openReadingPipe(1, address[1]); // read as B
  //
  // Default: NODE A
  radio.openWritingPipe(address[1]);
  radio.openReadingPipe(1, address[0]);
  radio.startListening();

  Serial.println(String("[RF] Ready ch=") + RF_CHANNEL);
}

// ----------------- Main Loop -----------------
void loop() {
  // RF receive
  if (radio.available()) {
    handleRfPacket();
  }

  // SOS button debounce + trigger
  bool btn = digitalRead(SOS_BTN_PIN);
  if (btn != lastBtnState) {
    lastBtnChange = millis();
    lastBtnState = btn;
  }
  if ((millis() - lastBtnChange) > BTN_DEBOUNCE_MS) {
    if (btn == LOW) {
      if (!sosFired) {
        sosFired = true;
        sendSosFramedFromFlash();
      }
    } else {
      sosFired = false;
    }
  }

  // Bluetooth receive (priority order)
  if (SerialBT.available()) {
    String msg = SerialBT.readStringUntil('\n');
    msg.trim();
    if (!msg.isEmpty()) {

      // 1) Voice markers
      if (msg == "<VOICE_START>") {
        if (channelBusy()) {
          SerialBT.println("<VOICE_DENY_BUSY>");
        } else {
          isVoice = true;
          txVoice = true;
          g_txSeq = 0;

          if (sendVoiceControl(VTYPE_START)) SerialBT.println("<VOICE_READY>");
          else {
            txVoice = false;
            isVoice = false;
            SerialBT.println("<VOICE_DENY_BUSY>");
          }
        }
      }
      else if (msg == "<VOICE_END>") {
        isVoice = false;

        if (txVoice) {
          txVoice = false;

          sendVoiceControl(VTYPE_END);
          delay(120);

          radio.stopListening();
          radio.flush_tx();
          radio.flush_rx();
          radio.clearStatusFlags();
          delay(30);
          radio.startListening();

          txLastEnd = millis();
        }

        SerialBT.println("<VOICE_DONE>");
        processQueuedProfileReqIfAny();
      }

      // 2) Voice chunks: if in voice, treat everything as chunk
      else if (isVoice) {
        sendVoiceLineWithSeq(msg);
      }

      // 3) JSON commands (strict)
      else if (msg.length() > 0 && msg.charAt(0) == '{' && msg.indexOf("\"command\"") >= 0) {
        handleSyncCommand(msg);
      }

      // 4) Normal chat framing
      else {
        if (voiceActive()) {
          SerialBT.println("{\"command\":\"busy_voice\"}");
        } else {
          String uid = myUidOrUnknown();
          String start = String("<MSG_START:") + uid + ">";
          String end   = "<MSG_END>";

          uint16_t seq = 0;
          seq = sendStringPacketSeqBase(TTYPE_TEXT, start, seq);
          delay(10);
          seq = sendStringPacketSeqBase(TTYPE_TEXT, msg, seq);
          delay(10);
          seq = sendStringPacketSeqBase(TTYPE_TEXT, end, seq);
        }
      }
    }
  }

  // Voice timeout (RX)
  if (rxVoice && (millis() - lastRxMillis > VOICE_TIMEOUT)) {
    rxVoice = false;
    SerialBT.println("<VOICE_END>");
    processQueuedProfileReqIfAny();
  }

  // Text completion flush (to phone)
  if (rxText && (millis() - lastTextPacketTime > TEXT_TIMEOUT_MS)) {
    if (textBuffer.length() > 0) {
      if (textBuffer.startsWith("<MSG_START:")) {
        int closePos = textBuffer.indexOf('>');
        if (closePos > 0) {
          String header = textBuffer.substring(0, closePos + 1);
          String body = textBuffer.substring(closePos + 1);

          body.replace("<MSG_END>", "");
          body.trim();

          SerialBT.println(header);
          if (body.length() > 0) SerialBT.println(body);
          SerialBT.println("<MSG_END>");
        } else {
          SerialBT.println("<MSG_START:UNKNOWN>");
          SerialBT.println(textBuffer);
          SerialBT.println("<MSG_END>");
        }
      } else {
        SerialBT.println("<MSG_START:UNKNOWN>");
        SerialBT.println(textBuffer);
        SerialBT.println("<MSG_END>");
      }
    }
    rxText = false;
    textBuffer = "";
    lastTextPacketTime = 0;
  }

  // Profile REQ flush (parse + respond)
  if (rxReq && (millis() - lastReqPacketTime > REQ_TIMEOUT_MS)) {
    if (reqBuffer.startsWith("REQ|")) {
      int p1 = reqBuffer.indexOf('|');
      int p2 = reqBuffer.indexOf('|', p1 + 1);
      int p3 = reqBuffer.indexOf('|', p2 + 1);
      if (p1 > 0 && p2 > p1 && p3 > p2) {
        String reqId = reqBuffer.substring(p1 + 1, p2);
        String destUid = reqBuffer.substring(p2 + 1, p3);
        String targetUid = reqBuffer.substring(p3 + 1);
        reqId.trim(); destUid.trim(); targetUid.trim();

        String myUid = myUidOrUnknown();

        // avoid responding during voice
        if (!voiceActive() && targetUid.length() > 0 && targetUid == myUid) {
          rfSendProfileResp(reqId, destUid);
        }
      }
    }
    rxReq = false;
    reqBuffer = "";
    lastReqPacketTime = 0;
    reqExpect = 0;
  }

  // Profile response flush (to phone)
  if (rxProf && (millis() - lastProfPacketTime > PROF_TIMEOUT_MS)) {
    if (profBuffer.startsWith("RSP|")) {
      int p1 = profBuffer.indexOf('|');
      int p2 = profBuffer.indexOf('|', p1 + 1);
      int p3 = profBuffer.indexOf('|', p2 + 1);
      if (p1 > 0 && p2 > p1 && p3 > p2) {
        String reqId = profBuffer.substring(p1 + 1, p2);
        String destUid = profBuffer.substring(p2 + 1, p3);
        String json = profBuffer.substring(p3 + 1);
        reqId.trim(); destUid.trim(); json.trim();

        String myUid = myUidOrUnknown();

        // only forward if not in voice and matches last request
        if (!voiceActive() && destUid == myUid && reqId == g_lastProfReqId) {
          String phoneResponse = String("{") +
            "\"command\":\"profile_response\"," +
            "\"data\":" + json +
          "}";
          SerialBT.println(phoneResponse);
        }
      }
    }
    rxProf = false;
    profBuffer = "";
    lastProfPacketTime = 0;
    profExpect = 0;
  }
}
