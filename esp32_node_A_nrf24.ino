/*
 * ESP32 nRF24L01 + Bluetooth SPP Voice Bridge (Node A)
 * FIXED + EXTENDED:
 *  - CRC verify + compute (crc8 excludes crc8 field; uses type+seq+payload)
 *  - Normal VOICE and normal TEXT behavior preserved
 *  - Text reassembly -> forwards: <MSG_START:...> + body + <MSG_END>
 *    - If sender already included <MSG_START:...>, receiver passes it through (important for SOS tagging)
 *  - SOS hardware button on GPIO4 (INPUT_PULLUP)
 *    - Sends SOS from flash as framed chat: <MSG_START:UIDSOS> + sos_msg + <MSG_END>
 *    - Uses continuous seq across the whole frame (prevents out-of-order logs)
 *  - Profile request/response over RF (requesting node only via destUid+reqId filter)
 *
 * NOTE:
 *  - RF is still effectively broadcast with current pipe setup,
 *    but only the requesting node processes the response (destUid match).
 */

 #include <SPI.h>
 #include <nRF24L01.h>
 #include <RF24.h>
 #include "BluetoothSerial.h"
 #include <Preferences.h>
 
 // ----------------- Pins / Config -----------------
 #define CE_PIN         26
 #define CSN_PIN        27
 #define BT_DEVICE_NAME "ESP32_NodeB_VoiceAC"
 
 // SOS tactile button (active LOW)
 #define SOS_BTN_PIN    4
 
 RF24 radio(CE_PIN, CSN_PIN);
 BluetoothSerial SerialBT;
 Preferences flashStorage;
 
 // 5-byte addresses (pipe names). index 0 = Node A (this), index 1 = Node B (peer).
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
 String   incomingBuffer = "";
 bool     isVoice = false;
 uint16_t g_txSeq = 0;
 
 bool     rxVoice = false;
 uint16_t rxExpect = 0;
 bool     txVoice = false;
 unsigned long txLastEnd = 0;
 
 // --- Timeout tracker for voice reception ---
 unsigned long lastRxMillis = 0;
 const unsigned long VOICE_TIMEOUT = 3000;
 
 // ----------------- State (Text reassembly) -----------------
 bool     rxText = false;
 uint16_t textExpect = 0;
 String   textBuffer = "";
 unsigned long lastTextPacketTime = 0;
 const unsigned long TEXT_TIMEOUT_MS = 900;
 
 // ----------------- State (Profile resp reassembly) -----------------
 bool     rxProf = false;
 uint16_t profExpect = 0;
 String   profBuffer = "";
 String   profReqId = "";
 String   profDestUid = "";
 unsigned long lastProfPacketTime = 0;
 const unsigned long PROF_TIMEOUT_MS = 1200;
 
 // ----------------- SOS button debounce -----------------
 bool lastBtnState = HIGH;
 unsigned long lastBtnChange = 0;
 const unsigned long BTN_DEBOUNCE_MS = 40;
 
 // ----------------- Helpers -----------------
 static inline String readFlashString(const char* key, const String& def = "") {
   flashStorage.begin("tulong", true);
   String v = flashStorage.getString(key, def.c_str());
   flashStorage.end();
   v.trim();
   return v;
 }
 
 static inline void writeSerialLine(const String& s) {
   Serial.println(s);
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
 
 // Compute CRC over: type + seq(2 bytes) + payload bytes (crc8 field excluded)
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
 
     const bool ok = sendRfRaw(buf, sizeof(VoiceHdr) + L);
     if (!ok) {
       Serial.println(String("[RF_VOICE_TX_ERR] DATA fail seq=") + g_txSeq);
       return false;
     }
 
     g_txSeq++;
     i += L;
     delay(4);
   }
   return true;
 }
 
 // ----------------- TEXT TX (existing behavior preserved) -----------------
 bool sendTextPacket(const String &msg) {
   const int N = msg.length();
   for (int i = 0; i < N; i += 28) {
     const uint8_t L = (uint8_t)min(28, N - i);
 
     uint8_t buf[sizeof(VoiceHdr) + 28] = {0};
     VoiceHdr *hdr = (VoiceHdr*)buf;
     hdr->type = TTYPE_TEXT;
     hdr->seq  = (uint16_t)(i / 28);
 
     memcpy(buf + sizeof(VoiceHdr), msg.c_str() + i, L);
     hdr->crc8 = crc8_hdr_payload(hdr->type, hdr->seq, buf + sizeof(VoiceHdr), L);
 
     if (!sendRfRaw(buf, sizeof(VoiceHdr) + L)) {
       Serial.println("[RF_TEXT_TX_ERR] send failed");
       return false;
     }
     delay(2);
   }
   return true;
 }
 
 // Send any RF "string message" with a given type, with seq starting from seqBase; returns next seq
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
   String uid = readFlashString("profile_uid", "");
   if (uid.length() == 0 || uid == "(not set)") uid = "UNKNOWN";
   String sos = readFlashString("sos_msg", "");
   if (sos.length() == 0 || sos == "(not set)") {
     Serial.println("[SOS_BTN] No sos_msg in flash. Not sending.");
     return;
   }
 
   String start = String("<MSG_START:") + uid + "SOS>";
   String end   = "<MSG_END>";
 
   Serial.println("[SOS_BTN] Clicked -> Sending SOS (framed like normal text)...");
   Serial.println("[SOS_BTN] " + start);
   Serial.println("[SOS_BTN] " + sos);
   Serial.println("[SOS_BTN] " + end);
 
   // Continuous seq across start/body/end using TEXT type to reuse receiver pipeline
   uint16_t seq = 0;
   seq = sendStringPacketSeqBase(TTYPE_TEXT, start, seq);
   delay(15);
   seq = sendStringPacketSeqBase(TTYPE_TEXT, sos, seq);
   delay(15);
   seq = sendStringPacketSeqBase(TTYPE_TEXT, end, seq);
 
   Serial.println(String("[SOS_BTN] Sent. nextSeq=") + seq);
 }
 
 // ----------------- Profile RF protocol -----------------
 // Payload format:
 //   REQ|<reqId>|<destUid>|<targetUid>
 //   RSP|<reqId>|<destUid>|{ "uid":"..","name":"..",... }   (JSON chunked)
 // Notes:
 // - We "broadcast" on RF pipe, but only destUid node processes/forwards.
 
 static inline String makeReqId() {
   // short id: millis + low random-ish
   uint32_t m = millis();
   uint16_t r = (uint16_t)(esp_random() & 0xFFFF);
   char buf[24];
   snprintf(buf, sizeof(buf), "%lu_%u", (unsigned long)m, (unsigned)r);
   return String(buf);
 }
 
 String jsonEscapeBasic(String s) {
   // minimal safety: replace quotes and newlines
   s.replace("\\", "\\\\");
   s.replace("\"", "'");
   s.replace("\n", " ");
   s.replace("\r", " ");
   return s;
 }
 
 bool rfSendProfileReq(const String& destUid, const String& targetUid) {
   String reqId = makeReqId();
   String payload = String("REQ|") + reqId + "|" + destUid + "|" + targetUid;
 
   Serial.println(String("[RF_PROF_REQ_TX] reqId=") + reqId + " destUid=" + destUid + " targetUid=" + targetUid);
 
   // send as PTYPE_REQ (chunking allowed, but small)
   uint16_t seq = 0;
   sendStringPacketSeqBase(PTYPE_REQ, payload, seq);
   return true;
 }
 
 bool rfSendProfileResp(const String& reqId, const String& destUid) {
   // read my profile from flash
   flashStorage.begin("tulong", true);
   String uid      = flashStorage.getString("profile_uid", "");
   String name     = flashStorage.getString("profile_name", "");
   String username = flashStorage.getString("p_user", "");
   String street   = flashStorage.getString("profile_street", "");
   String province = flashStorage.getString("p_prov", "");
   String city     = flashStorage.getString("profile_city", "");
   String barangay = flashStorage.getString("p_brgy", "");
   String suffix   = flashStorage.getString("profile_suffix", "");
   flashStorage.end();
 
   uid.trim(); name.trim(); username.trim(); street.trim(); province.trim(); city.trim(); barangay.trim(); suffix.trim();
 
   // build JSON (minimal escaping)
   String j = "{";
   j += "\"uid\":\"" + jsonEscapeBasic(uid) + "\",";
   j += "\"name\":\"" + jsonEscapeBasic(name) + "\",";
   j += "\"username\":\"" + jsonEscapeBasic(username) + "\",";
   j += "\"street\":\"" + jsonEscapeBasic(street) + "\",";
   j += "\"province\":\"" + jsonEscapeBasic(province) + "\",";
   j += "\"city\":\"" + jsonEscapeBasic(city) + "\",";
   j += "\"barangay\":\"" + jsonEscapeBasic(barangay) + "\",";
   j += "\"suffix\":\"" + jsonEscapeBasic(suffix) + "\"";
   j += "}";
 
   String payload = String("RSP|") + reqId + "|" + destUid + "|" + j;
 
   Serial.println(String("[RF_PROF_RESP_TX] reqId=") + reqId + " -> destUid=" + destUid + " bytes=" + payload.length());
 
   uint16_t seq = 0;
   seq = sendStringPacketSeqBase(PTYPE_RESP, payload, seq);
 
   Serial.println(String("[RF_PROF_RESP_TX] sent chunks, nextSeq=") + seq);
   return true;
 }
 
 // ----------------- JSON Helper (BT sync commands) -----------------
 String extractJsonValue(String json, String key) {
   String searchKey = "\"" + key + "\":";
   int startPos = json.indexOf(searchKey);
   if (startPos < 0) return "";
 
   startPos += searchKey.length();
   while (startPos < (int)json.length() && (json.charAt(startPos) == ' ' || json.charAt(startPos) == '\t')) startPos++;
 
   if (startPos < (int)json.length() && json.charAt(startPos) == '"') {
     startPos++;
     int endPos = json.indexOf("\"", startPos);
     if (endPos > startPos) return json.substring(startPos, endPos);
   } else {
     int endPos = startPos;
     while (endPos < (int)json.length() &&
            json.charAt(endPos) != ',' &&
            json.charAt(endPos) != '}' &&
            json.charAt(endPos) != ']' &&
            json.charAt(endPos) != ' ') {
       endPos++;
     }
     return json.substring(startPos, endPos);
   }
   return "";
 }
 
 // ----------------- Flash save functions -----------------
 void saveProfileToFlash(String name, String username, String street, String province, String city, String barangay, String uid, String suffix) {
   flashStorage.begin("tulong", false);
 
   bool savedName     = flashStorage.putString("profile_name", name);
   bool savedUsername = flashStorage.putString("p_user", username);
   bool savedStreet   = flashStorage.putString("profile_street", street);
   bool savedProvince = flashStorage.putString("p_prov", province);
   bool savedCity     = flashStorage.putString("profile_city", city);
   bool savedBarangay = flashStorage.putString("p_brgy", barangay);
   bool savedUid      = flashStorage.putString("profile_uid", uid);
   bool savedSuffix   = flashStorage.putString("profile_suffix", suffix);
 
   bool okAll = savedName && savedUsername && savedStreet && savedProvince && savedCity && savedBarangay && savedUid && savedSuffix;
   if (okAll) {
     int count = flashStorage.getInt("p_cnt", 0) + 1;
     flashStorage.putInt("p_cnt", count);
     flashStorage.end();
 
     Serial.println("[FLASH] Profile saved OK.");
     Serial.println(String("[FLASH] p_cnt=") + count);
   } else {
     flashStorage.end();
     Serial.println("[FLASH_ERR] Profile save FAILED.");
   }
 }
 
 void saveSosToFlash(String message) {
   flashStorage.begin("tulong", false);
   bool savedMessage = flashStorage.putString("sos_msg", message);
 
   if (savedMessage) {
     int count = flashStorage.getInt("s_cnt", 0) + 1;
     flashStorage.putInt("s_cnt", count);
     flashStorage.end();
 
     Serial.println(String("[FLASH] SOS saved OK. s_cnt=") + count);
   } else {
     flashStorage.end();
     Serial.println("[FLASH_ERR] SOS save FAILED.");
   }
 }
 
 void verifyStoredData() {
   flashStorage.begin("tulong", true);
 
   String profileName     = flashStorage.getString("profile_name", "(not set)");
   String profileUsername = flashStorage.getString("p_user", "(not set)");
   String profileStreet   = flashStorage.getString("profile_street", "(not set)");
   String profileProvince = flashStorage.getString("p_prov", "(not set)");
   String profileCity     = flashStorage.getString("profile_city", "(not set)");
   String profileBarangay = flashStorage.getString("p_brgy", "(not set)");
   String profileUid      = flashStorage.getString("profile_uid", "(not set)");
   String profileSuffix   = flashStorage.getString("profile_suffix", "(not set)");
   String sosMessage      = flashStorage.getString("sos_msg", "(not set)");
 
   int profileCount       = flashStorage.getInt("p_cnt", 0);
   int sosCount           = flashStorage.getInt("s_cnt", 0);
 
   flashStorage.end();
 
   Serial.println(String("[VERIFY] profile: ") + profileName + " / " + profileUsername);
   Serial.println(String("[VERIFY] UID: ") + profileUid);
   Serial.println(String("[VERIFY] suffix: ") + profileSuffix);
   Serial.println(String("[VERIFY] address: ") + profileStreet + ", " + profileBarangay + ", " + profileCity + ", " + profileProvince);
   Serial.println(String("[VERIFY] sos: ") + sosMessage);
   Serial.println(String("[VERIFY] counts p=") + profileCount + " s=" + sosCount);
 }
 
 // ----------------- BT Command Handler -----------------
 void handleSyncCommand(String msg) {
   Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   Serial.println("[BT_SYNC] handleSyncCommand()");
   Serial.println(String("[BT_SYNC] Raw: ") + msg);
 
   String command = extractJsonValue(msg, "command");
   Serial.println(String("[BT_SYNC] command=") + command);
 
  if (command == "sync_profile") {
    String name = extractJsonValue(msg, "name");
    String username = extractJsonValue(msg, "username");
    String street = extractJsonValue(msg, "street");
    String province = extractJsonValue(msg, "province");
    String city = extractJsonValue(msg, "city");
    String barangay = extractJsonValue(msg, "barangay");
    String uid = extractJsonValue(msg, "uid");
    String suffix = extractJsonValue(msg, "suffix");

    if (name.length() > 0 || username.length() > 0) {
      // Preserve existing UID - only use new UID if no existing UID
      String existingUid = readFlashString("profile_uid", "");
      if (existingUid.length() > 0 && existingUid != "(not set)") {
        // Keep existing UID, ignore UID from update message
        uid = existingUid;
        Serial.println(String("[BT_SYNC] preserving existing UID: ") + uid);
      } else {
        // No existing UID - require UID from app (must be fetched from server)
        if (uid.length() == 0 || uid == "UNKNOWN") {
          Serial.println("[BT_SYNC_ERR] No UID provided and no existing UID. App must fetch UID first.");
          Serial.println("[BT_SYNC_ERR] Profile not saved. Please sync UID from app.");
          return; // Don't save without UID
        }
        // First time setup - use UID from message (fetched by app)
        Serial.println(String("[BT_SYNC] using UID from app: ") + uid);
      }
      
      Serial.println("[BT_SYNC] saving profile...");
      saveProfileToFlash(name, username, street, province, city, barangay, uid, suffix);
    } else {
      Serial.println("[BT_SYNC_ERR] invalid profile: missing name/username");
    }
   } else if (command == "sync_sos") {
     String message = extractJsonValue(msg, "message");
     if (message.length() > 0) {
       Serial.println("[BT_SYNC] saving SOS...");
       saveSosToFlash(message);
     } else {
       Serial.println("[BT_SYNC_ERR] invalid SOS: empty message");
     }
   } else if (command == "get_profile") {
     // Request profile details for a UID
     String targetUid = extractJsonValue(msg, "uid");
     targetUid.trim();
     Serial.println(String("[BT_GET_PROFILE] requested uid=") + targetUid);
 
     String myUid = readFlashString("profile_uid", "");
     if (myUid.length() == 0 || myUid == "(not set)") myUid = "UNKNOWN";
 
     // local hit?
     if (targetUid.length() > 0 && targetUid == myUid) {
       Serial.println("[BT_GET_PROFILE] local match -> sending profile_response to phone");
 
       flashStorage.begin("tulong", true);
       String uid      = flashStorage.getString("profile_uid", "");
       String name     = flashStorage.getString("profile_name", "");
       String username = flashStorage.getString("p_user", "");
       String street   = flashStorage.getString("profile_street", "");
       String province = flashStorage.getString("p_prov", "");
       String city     = flashStorage.getString("profile_city", "");
       String barangay = flashStorage.getString("p_brgy", "");
       String suffix   = flashStorage.getString("profile_suffix", "");
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
           "\"suffix\":\"" + jsonEscapeBasic(suffix) + "\"" +
         "}" +
       "}";
 
       SerialBT.println(response);
       Serial.println("[BT_TX] profile_response (local) sent");
     } else {
       // broadcast RF request; response will be filtered by destUid (= myUid)
       if (targetUid.length() == 0) {
         Serial.println("[BT_GET_PROFILE_ERR] empty target uid");
       } else {
         rfSendProfileReq(myUid, targetUid);
       }
     }
   } else {
     Serial.println(String("[BT_SYNC_ERR] unknown command: ") + command);
   }
 
   Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
 }
 
 // ----------------- RF receive handler -----------------
 void handleRfPacket() {
   uint8_t len = radio.getDynamicPayloadSize();
   if (len == 0 || len > 32) { radio.flush_rx(); return; }
 
   uint8_t raw[32];
   radio.read(raw, len);
   lastRxMillis = millis();
 
   if (len < sizeof(VoiceHdr)) {
     // Legacy plain text
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
 
   // ----------------- VOICE -----------------
   if (hdr->type == VTYPE_START) {
     rxVoice = true; rxExpect = 0; incomingBuffer = "";
     Serial.println("[RF_VOICE_RX] START");
     if (txVoice) {
       txVoice = false; isVoice = false;
       SerialBT.println("<VOICE_DENY_BUSY>");
     }
     return;
   }
 
   if (hdr->type == VTYPE_END) {
     rxVoice = false;
     Serial.println("[RF_VOICE_RX] END -> to phone");
     SerialBT.println("<VOICE_START>");
     SerialBT.println(incomingBuffer);
     SerialBT.println("<VOICE_END>");
     incomingBuffer = "";
     return;
   }
 
   if (hdr->type == VTYPE_DATA) {
     const uint16_t seq = hdr->seq;
     if (!rxVoice) {
       Serial.println("[RF_VOICE_RX_WARN] DATA while not in voice mode; drop");
       return;
     }
     if (seq != rxExpect) {
       Serial.println(String("[RF_VOICE_RX_LOSS] got=") + seq + " expect=" + rxExpect);
       rxExpect = seq + 1;
     } else rxExpect++;
     incomingBuffer += String((char*)payload, payLen);
     return;
   }
 
   // ----------------- TEXT (chat) -----------------
   if (hdr->type == TTYPE_TEXT) {
     const uint16_t seq = hdr->seq;
 
     if (!rxText) {
       rxText = true;
       textBuffer = "";
       textExpect = seq + 1;
       Serial.println("[RF_TEXT_RX] new message");
     }
 
     lastTextPacketTime = millis();
 
     if (seq != textExpect - 1) {
       // Expect was set to seq+1 on start; so compare against expected-1 per packet
       // But keep a simple check:
       if (seq != (uint16_t)(textExpect - 1)) {
         // If packets come in weird, log and resync
         Serial.println(String("[RF_LOSS] TEXT out-of-order: got=") + seq + " expect=" + (textExpect - 1));
       }
       textExpect = seq + 2;
     } else {
       textExpect++;
     }
 
     textBuffer += String((char*)payload, payLen);
     return;
   }
 
   // ----------------- PROFILE REQ -----------------
   if (hdr->type == PTYPE_REQ) {
     String s((char*)payload, payLen);
     // accumulate small requests as single string (should fit)
     // Expected: REQ|reqId|destUid|targetUid
     Serial.println(String("[RF_PROF_REQ_RX] chunk seq=") + hdr->seq + " '" + s + "'");
 
     // For safety, accept only first chunk seq=0 (your REQ should be short)
     if (hdr->seq != 0) return;
 
     if (!s.startsWith("REQ|")) return;
 
     int p1 = s.indexOf('|');               // after REQ
     int p2 = s.indexOf('|', p1 + 1);       // after reqId
     int p3 = s.indexOf('|', p2 + 1);       // after destUid
     if (p1 < 0 || p2 < 0 || p3 < 0) return;
 
     String reqId = s.substring(p1 + 1, p2);
     String destUid = s.substring(p2 + 1, p3);
     String targetUid = s.substring(p3 + 1);
     reqId.trim(); destUid.trim(); targetUid.trim();
 
     String myUid = readFlashString("profile_uid", "");
     if (myUid.length() == 0 || myUid == "(not set)") myUid = "UNKNOWN";
 
     Serial.println(String("[RF_PROF_REQ_RX] reqId=") + reqId + " destUid=" + destUid + " targetUid=" + targetUid + " myUid=" + myUid);
 
     // Only the node owning targetUid should answer
     if (targetUid.length() > 0 && targetUid == myUid) {
       Serial.println("[RF_PROF_REQ_RX] target matches me -> sending RSP");
       rfSendProfileResp(reqId, destUid);
     } else {
       Serial.println("[RF_PROF_REQ_RX] not for me -> ignore");
     }
     return;
   }
 
   // ----------------- PROFILE RESP -----------------
   if (hdr->type == PTYPE_RESP) {
     String s((char*)payload, payLen);
 
     if (!rxProf) {
       rxProf = true;
       profBuffer = "";
       profExpect = hdr->seq; // start at first received seq
       profReqId = "";
       profDestUid = "";
       Serial.println("[RF_PROF_RESP_RX] new resp stream");
     }
 
     lastProfPacketTime = millis();
 
     // naive order check
     if (hdr->seq != profExpect) {
       Serial.println(String("[RF_PROF_RESP_RX_LOSS] got=") + hdr->seq + " expect=" + profExpect);
       profExpect = hdr->seq;
     }
     profExpect++;
 
     profBuffer += s;
 
     // We will finalize on timeout and then parse header fields (RSP|reqId|destUid|{json})
     return;
   }
 
   Serial.println(String("[RF_WARN] Unknown type=") + hdr->type);
 }
 
 // ----------------- Setup -----------------
 void setup() {
   Serial.begin(115200);
   delay(300);
 
   SerialBT.begin(BT_DEVICE_NAME);
   delay(300);
 
   pinMode(SOS_BTN_PIN, INPUT_PULLUP);
 
   Serial.println("=== ESP32 Voice Bridge (Node A: nRF24 + SPP) ===");
   Serial.println(String("[BT] Ready: ") + BT_DEVICE_NAME);
 
   // Flash verify
   flashStorage.begin("tulong", true);
   int initProfileCount = flashStorage.getInt("p_cnt", 0);
   int initSosCount = flashStorage.getInt("s_cnt", 0);
   flashStorage.end();
 
   Serial.println(String("[FLASH] profile count: ") + initProfileCount);
   Serial.println(String("[FLASH] sos count: ") + initSosCount);
 
   if (initProfileCount > 0 || initSosCount > 0) verifyStoredData();
 
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
 
   // Your existing direction (keep as you used before)
   radio.openWritingPipe(address[0]);
   radio.openReadingPipe(1, address[1]);
   radio.startListening();
 
   Serial.println(String("[RF] Ready ch=") + RF_CHANNEL +
                  " dataRate=" + (RF_DATARATE == RF24_250KBPS ? "250k" : "1M") +
                  " PA=" + (RF_PALEVEL == RF24_PA_MIN ? "MIN" :
                            RF_PALEVEL == RF24_PA_LOW ? "LOW" :
                            RF_PALEVEL == RF24_PA_HIGH ? "HIGH" : "MAX"));
 }
 
 // ----------------- Main Loop -----------------
 void loop() {
   // RF receive
   if (radio.available()) {
     Serial.println("[RF] packet available");
     handleRfPacket();
   }
 
   // SOS button debounce + trigger
   bool btn = digitalRead(SOS_BTN_PIN);
   if (btn != lastBtnState) {
     lastBtnChange = millis();
     lastBtnState = btn;
   }
   if ((millis() - lastBtnChange) > BTN_DEBOUNCE_MS) {
     // stable
     if (btn == LOW) {
       // fire once per press: wait until release
       static bool fired = false;
       if (!fired) {
         fired = true;
         sendSosFramedFromFlash();
       }
     } else {
       static bool fired = false;
       fired = false;
     }
   }
 
   // Bluetooth receive
   if (SerialBT.available()) {
     String msg = SerialBT.readStringUntil('\n');
     msg.trim();
     if (!msg.isEmpty()) {
       Serial.println("[BT_RX] " + msg);
 
       if (msg.indexOf("\"command\":") >= 0) {
         handleSyncCommand(msg);
       } else if (msg == "<VOICE_START>") {
         Serial.println(String("[BT] <VOICE_START> busy=") + channelBusy());
         if (channelBusy()) {
           SerialBT.println("<VOICE_DENY_BUSY>");
         } else {
           isVoice = true;
           txVoice = true;
           g_txSeq = 0;
 
           if (sendVoiceControl(VTYPE_START)) {
             SerialBT.println("<VOICE_READY>");
           } else {
             txVoice = false;
             isVoice = false;
             SerialBT.println("<VOICE_DENY_BUSY>");
           }
         }
       } else if (msg == "<VOICE_END>") {
         isVoice = false;
 
         if (txVoice) {
           txVoice = false;
 
           sendVoiceControl(VTYPE_END);
           delay(200);
 
           radio.stopListening();
           radio.flush_tx();
           radio.flush_rx();
           radio.clearStatusFlags();
           delay(40);
           radio.startListening();
 
           txLastEnd = millis();
         }
 
         SerialBT.println("<VOICE_DONE>");
       } else {
         if (isVoice) {
           sendVoiceLineWithSeq(msg);
         } else {
           // normal text -> RF
           Serial.println(String("[BT_TEXT_TX] len=") + msg.length());
           sendTextPacket(msg);
         }
       }
     }
   }
 
   // --- Voice timeout flush ---
   if (rxVoice && (millis() - lastRxMillis > VOICE_TIMEOUT)) {
     rxVoice = false;
     Serial.println("[RF_WARN] Voice timeout — assuming end");
     if (incomingBuffer.length() > 0) {
       SerialBT.println("<VOICE_START>");
       SerialBT.println(incomingBuffer);
       SerialBT.println("<VOICE_END>");
       incomingBuffer = "";
     }
   }
 
   // --- Text completion flush (to phone) ---
   if (rxText && (millis() - lastTextPacketTime > TEXT_TIMEOUT_MS)) {
     Serial.println(String("[RF_TEXT_RX] flush len=") + textBuffer.length());
 
     if (textBuffer.length() > 0) {
       // If sender already embedded a header (<MSG_START:...>), pass it through.
       if (textBuffer.startsWith("<MSG_START:")) {
         int closePos = textBuffer.indexOf('>');
         if (closePos > 0) {
           String header = textBuffer.substring(0, closePos + 1);
           String body = textBuffer.substring(closePos + 1);
 
           Serial.println(String("[BT_TX] header(pass)=") + header);
           SerialBT.println(header);
           SerialBT.println(body);
           SerialBT.println("<MSG_END>");
         } else {
           // malformed; fallback
           String myUid = readFlashString("profile_uid", "");
           if (myUid.length() == 0 || myUid == "(not set)") myUid = "UNKNOWN";
           String header = String("<MSG_START:") + myUid + ">";
 
           Serial.println(String("[BT_TX] header(fallback)=") + header);
           SerialBT.println(header);
           SerialBT.println(textBuffer);
           SerialBT.println("<MSG_END>");
         }
       } else {
         // No embedded header, keep your old behavior: generate <MSG_START:UID>
         String myUid = readFlashString("profile_uid", "");
         if (myUid.length() == 0 || myUid == "(not set)") myUid = "UNKNOWN";
         String header = String("<MSG_START:") + myUid + ">";
 
         Serial.println(String("[BT_TX] header(gen)=") + header);
         SerialBT.println(header);
         SerialBT.println(textBuffer);
         SerialBT.println("<MSG_END>");
       }
     }
 
     rxText = false;
     textBuffer = "";
     lastTextPacketTime = 0;
   }
 
   // --- Profile response flush (to phone, requesting node only) ---
   if (rxProf && (millis() - lastProfPacketTime > PROF_TIMEOUT_MS)) {
     Serial.println(String("[RF_PROF_RESP_RX] flush bytes=") + profBuffer.length());
 
     // Expected: RSP|reqId|destUid|{json...}
     if (profBuffer.startsWith("RSP|")) {
       int p1 = profBuffer.indexOf('|');             // after RSP
       int p2 = profBuffer.indexOf('|', p1 + 1);     // after reqId
       int p3 = profBuffer.indexOf('|', p2 + 1);     // after destUid
       if (p1 > 0 && p2 > p1 && p3 > p2) {
         String reqId = profBuffer.substring(p1 + 1, p2);
         String destUid = profBuffer.substring(p2 + 1, p3);
         String json = profBuffer.substring(p3 + 1);
 
         reqId.trim(); destUid.trim(); json.trim();
 
         String myUid = readFlashString("profile_uid", "");
         if (myUid.length() == 0 || myUid == "(not set)") myUid = "UNKNOWN";
 
         Serial.println(String("[RF_PROF_RESP_RX] reqId=") + reqId + " destUid=" + destUid + " myUid=" + myUid);
 
         if (destUid == myUid) {
           // Forward to phone
           String phoneResponse = String("{") +
             "\"command\":\"profile_response\"," +
             "\"data\":" + json +
           "}";
 
           SerialBT.println(phoneResponse);
           Serial.println("[BT_TX] profile_response forwarded to phone");
         } else {
           Serial.println("[RF_PROF_RESP_RX] not my destUid -> drop");
         }
       } else {
         Serial.println("[RF_PROF_RESP_RX_ERR] bad format");
       }
     } else {
       Serial.println("[RF_PROF_RESP_RX_ERR] missing RSP| prefix");
     }
 
     rxProf = false;
     profBuffer = "";
     lastProfPacketTime = 0;
     profExpect = 0;
   }
 
   // periodic debug
   static unsigned long lastDbg = 0;
   if (millis() - lastDbg > 3000) {
     lastDbg = millis();
     Serial.println(String("[DBG] busy=") + channelBusy() +
                    " txVoice=" + txVoice +
                    " rxVoice=" + rxVoice +
                    " rxText=" + rxText +
                    " rxProf=" + rxProf +
                    " sinceLastEnd=" + (millis() - txLastEnd));
   }
 }
 