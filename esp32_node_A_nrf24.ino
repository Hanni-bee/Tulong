/*
 * ESP32 nRF24L01 + Bluetooth SPP Voice Bridge (Node A)
 * Mirror of your Node B code, with reversed pipes and BT name.
 *
 * Phone (Flutter)   <—SPP—>   ESP32 Node A (this file)   <—nRF24—>   ESP32 Node B   <—SPP—>   Phone
 *
 * App protocol stays the same:
 *   <VOICE_START>\n
 *   <base64 lines (any length; ESP splits to ≤28 chars per RF pkt)>\n
 *   <VOICE_END>\n
 *
 * RF payload (max 32B): 3B header + 1B CRC + up to 28 ASCII chars
 *   struct VoiceHdr { uint8_t type; uint16_t seq; uint8_t crc8; } // little-endian seq
 *   type: 0xD0 = START, 0xD1 = DATA, 0xD2 = END
 */

 #include <SPI.h>
 #include <nRF24L01.h>
 #include <RF24.h>
 #include "BluetoothSerial.h"
 #include <Preferences.h>
 
 // ----------------- Pins / Config -----------------
 #define CE_PIN         26
 #define CSN_PIN        27
 #define BT_DEVICE_NAME "ESP32_NodeA_VoiceAC"
 
 RF24 radio(CE_PIN, CSN_PIN);
 BluetoothSerial SerialBT;
 Preferences flashStorage;
 
 // 5-byte addresses (pipe names). index 0 = Node A (this), index 1 = Node B (peer).
 const byte address[][6] = {"1Node", "2Node"};
 
 // nRF settings
 #define RF_CHANNEL     108          // 2.508 GHz
 #define RF_DATARATE    RF24_250KBPS // robust; try RF24_1MBPS if you want faster
 #define RF_PALEVEL     RF24_PA_LOW  // PA_MAX needs strong 3V3 + decoupling
 
 // ----------------- Voice RF header -----------------
 enum : uint8_t { VTYPE_START = 0xD0, VTYPE_DATA = 0xD1, VTYPE_END = 0xD2 };
 
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
 
 
 // ----------------- Logging Helper -----------------
 void logEvent(const String &tag, const String &msg) {
   String log = "[" + String(millis()) + "][" + tag + "] " + msg;
   Serial.println(log);
   SerialBT.println(log);
   // Force flush to ensure logs appear immediately
   Serial.flush();
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
   radio.clearStatusFlags();   // <--- YOUR VERSION USES THIS
   delay(5);
   radio.startListening();
 
   return false;
 }
 
 
 bool sendTextPacket(const String &msg) {
     int N = msg.length();
     for (int i = 0; i < N; i += 28) {
         uint8_t L = min(28, N - i);
 
         uint8_t buf[4 + 28];
         VoiceHdr *hdr = (VoiceHdr*)buf;
         hdr->type = 0xA0;   // new type for TEXT
         hdr->seq  = i / 28;
 
         memcpy(buf + sizeof(VoiceHdr), msg.c_str() + i, L);
         hdr->crc8 = crc8_calc(buf, sizeof(VoiceHdr) + L - 1);
 
         if (!sendRfRaw(buf, sizeof(VoiceHdr) + L)) return false;
     }
     return true;
 }
 
 
 bool channelBusy() {
   // Simple approach: check if we’re receiving something or just finished TX recently
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
   //logEvent(ok ? "RF_TX" : "RF_ERR",
         //   String(type == VTYPE_START ? "V-START" : "V-END") + (ok ? " OK" : " FAIL"));
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
    // logEvent(ok ? "RF_TX" : "RF_ERR",
      //        String("V-DATA seq=")+g_txSeq+" len="+L+(ok?" OK":" FAIL"));
     g_txSeq++;
     i += L;
 
     if (!ok) return false;   // early out if radio write failed
     delay(5);                // gentle pacing
   }
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
       // Forward completed VM to phone (unchanged protocol)
       SerialBT.println("<VOICE_START>");
       SerialBT.println(incomingBuffer);
       SerialBT.println("<VOICE_END>");
      // logEvent("BT", "Sent voice to Flutter (" + String(incomingBuffer.length()) + " chars)");
       incomingBuffer = "";
       return;
     }
 
     if (hdr->type == VTYPE_DATA) {
       const uint16_t seq = hdr->seq;
       const uint8_t  payLen = len - sizeof(VoiceHdr); // ASCII chars count
 
       if (!rxVoice) {
         logEvent("RF_WARN", "V-DATA while not in voice mode; dropping");
         return;
       }
 
       if (seq != rxExpect) {
         logEvent("RF_LOSS", String("Missing/out-of-order: got seq=")+seq+" expect="+rxExpect);
         rxExpect = seq + 1; // resync to continue (simple strategy)
       } else {
         rxExpect++;
       }
 
       // Append ASCII Base64 to buffer
       incomingBuffer += String((char*)(raw + sizeof(VoiceHdr)), payLen);
     //  logEvent("RF", String("V-DATA seq=")+seq+" +"+payLen+" chars total="+incomingBuffer.length());
       return;
     }
 // ----------------- TEXT PACKET HANDLING (0xA0) -----------------
 if (hdr->type == 0xA0) {
     uint16_t seq = hdr->seq;
     uint8_t payLen = len - sizeof(VoiceHdr);
 
     static bool rxText = false;
     static uint16_t textExpect = 0;
     static String textBuffer = "";
 
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
 
     // For simplicity, deliver text immediately per packet
     SerialBT.println(textBuffer);
 
     // Reset text state (optional: depends on your design)
     rxText = false;
     textBuffer = "";
 
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
    // logEvent("BT", "Sent voice to Flutter (" + String(incomingBuffer.length()) + " chars)");
     incomingBuffer = "";
     return;
   }
 
   if (!rxVoice) {
     //logEvent("RF_RX", "Text: " + text);
     SerialBT.println(String("From B: ") + text);
   }
 }
 
 // ----------------- JSON Helper -----------------
 String extractJsonValue(String json, String key) {
   String searchKey = "\"" + key + "\":";
   int startPos = json.indexOf(searchKey);
   if (startPos < 0) return "";
   
   startPos += searchKey.length();
   // Skip whitespace
   while (startPos < json.length() && (json.charAt(startPos) == ' ' || json.charAt(startPos) == '\t')) {
     startPos++;
   }
   
   // Check if value is quoted string
   if (startPos < json.length() && json.charAt(startPos) == '"') {
     startPos++;  // Skip opening quote
     int endPos = json.indexOf("\"", startPos);
     if (endPos > startPos) {
       return json.substring(startPos, endPos);
     }
   } else {
     // Unquoted value (number, boolean, etc.)
     int endPos = startPos;
     while (endPos < json.length() && 
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

 // ----------------- Flash Storage Functions -----------------
 void saveProfileToFlash(String name, String username, String street, String province, String city, String barangay) {
   logEvent("FLASH", "📥 RECEIVED PROFILE DATA FROM PHONE");
   logEvent("FLASH", "   Name: " + name);
   logEvent("FLASH", "   Username: " + username);
   logEvent("FLASH", "   Street: " + street);
   logEvent("FLASH", "   Province: " + province);
   logEvent("FLASH", "   City: " + city);
   logEvent("FLASH", "   Barangay: " + barangay);
   
   logEvent("FLASH", "💾 Saving profile data to flash memory...");
   flashStorage.begin("tulong", false);
   
   Serial.println("🔵 [FLASH] Writing profile fields to flash...");
   Serial.flush();
   
   bool savedName = flashStorage.putString("profile_name", name);
   bool savedUsername = flashStorage.putString("profile_username", username);
   bool savedStreet = flashStorage.putString("profile_street", street);
   bool savedProvince = flashStorage.putString("profile_province", province);
   bool savedCity = flashStorage.putString("profile_city", city);
   bool savedBarangay = flashStorage.putString("profile_barangay", barangay);
   
   Serial.println("🔵 [FLASH] Save results:");
   Serial.println("   Name: " + String(savedName ? "OK ✅" : "FAIL ❌"));
   Serial.println("   Username: " + String(savedUsername ? "OK ✅" : "FAIL ❌"));
   Serial.println("   Street: " + String(savedStreet ? "OK ✅" : "FAIL ❌"));
   Serial.println("   Province: " + String(savedProvince ? "OK ✅" : "FAIL ❌"));
   Serial.println("   City: " + String(savedCity ? "OK ✅" : "FAIL ❌"));
   Serial.println("   Barangay: " + String(savedBarangay ? "OK ✅" : "FAIL ❌"));
   Serial.flush();
   
   logEvent("FLASH", "   Save results - Name: " + String(savedName ? "OK" : "FAIL") + 
                     ", Username: " + String(savedUsername ? "OK" : "FAIL") +
                     ", Street: " + String(savedStreet ? "OK" : "FAIL") +
                     ", Province: " + String(savedProvince ? "OK" : "FAIL") +
                     ", City: " + String(savedCity ? "OK" : "FAIL") +
                     ", Barangay: " + String(savedBarangay ? "OK" : "FAIL"));
   
   if (savedName && savedUsername && savedStreet && savedProvince && savedCity && savedBarangay) {
     int count = flashStorage.getInt("profile_saved_count", 0) + 1;
     bool savedCount = flashStorage.putInt("profile_saved_count", count);
     flashStorage.end();
     
     if (savedCount) {
       Serial.println("🔵 [FLASH] ✅ Profile saved! Count: " + String(count));
       Serial.flush();
       logEvent("FLASH", "✅ Profile data saved to flash memory successfully");
       logEvent("FLASH", "   Save count: " + String(count));
       
       // Reply with count
       String reply = "{\"profile_saved_count\":" + String(count) + "}";
       Serial.println("🔵 [FLASH] 📤 Sending reply to phone: " + reply);
       Serial.flush();
       SerialBT.println(reply);
       logEvent("FLASH", "📤 Sent reply to phone: " + reply);
       Serial.println("🔵 [FLASH] ✅ Reply sent!");
       Serial.flush();
       
       // Verify by reading back
       verifyStoredData();
     } else {
       logEvent("FLASH_ERR", "❌ Failed to save profile count");
       flashStorage.end();
     }
   } else {
     logEvent("FLASH_ERR", "❌ Failed to save profile data - one or more fields failed");
     flashStorage.end();
   }
 }

 void saveSosToFlash(String message) {
   Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   Serial.println("🔵 [FLASH] ===== saveSosToFlash() CALLED =====");
   Serial.println("🔵 [FLASH] 📥 RECEIVED SOS MESSAGE FROM PHONE");
   Serial.println("🔵 [FLASH] Message: \"" + message + "\"");
   Serial.println("🔵 [FLASH] Message length: " + String(message.length()) + " characters");
   Serial.flush();
   
   logEvent("FLASH", "📥 RECEIVED SOS MESSAGE FROM PHONE");
   logEvent("FLASH", "   Message: \"" + message + "\"");
   logEvent("FLASH", "   Message length: " + String(message.length()) + " characters");
   
   Serial.println("🔵 [FLASH] 💾 Opening flash storage...");
   Serial.flush();
   logEvent("FLASH", "💾 Saving SOS message to flash memory...");
   flashStorage.begin("tulong", false);
   
   Serial.println("🔵 [FLASH] Writing SOS message to flash...");
   Serial.flush();
   
   bool savedMessage = flashStorage.putString("sos_message", message);
   
   Serial.println("🔵 [FLASH] Save result: " + String(savedMessage ? "OK ✅" : "FAIL ❌"));
   Serial.flush();
   
   logEvent("FLASH", "   Save result - Message: " + String(savedMessage ? "OK" : "FAIL"));
   
   if (savedMessage) {
     int count = flashStorage.getInt("sos_saved_count", 0) + 1;
     bool savedCount = flashStorage.putInt("sos_saved_count", count);
     flashStorage.end();
     
     if (savedCount) {
       Serial.println("🔵 [FLASH] ✅ SOS saved! Count: " + String(count));
       Serial.flush();
       logEvent("FLASH", "✅ SOS message saved to flash memory successfully");
       logEvent("FLASH", "   Save count: " + String(count));
       
       // Reply with count
       String reply = "{\"sos_saved_count\":" + String(count) + "}";
       Serial.println("🔵 [FLASH] 📤 Sending reply to phone: " + reply);
       Serial.flush();
       SerialBT.println(reply);
       logEvent("FLASH", "📤 Sent reply to phone: " + reply);
       Serial.println("🔵 [FLASH] ✅ Reply sent!");
       Serial.flush();
       
       // Verify by reading back
       verifyStoredData();
     } else {
       logEvent("FLASH_ERR", "❌ Failed to save SOS count");
       flashStorage.end();
     }
   } else {
     logEvent("FLASH_ERR", "❌ Failed to save SOS message");
     flashStorage.end();
   }
 }

 // ----------------- Verify Stored Data -----------------
 void verifyStoredData() {
   logEvent("FLASH", "🔍 VERIFYING STORED DATA IN FLASH MEMORY");
   flashStorage.begin("tulong", true); // Read-only mode
   
   String profileName = flashStorage.getString("profile_name", "(not set)");
   String profileUsername = flashStorage.getString("profile_username", "(not set)");
   String profileStreet = flashStorage.getString("profile_street", "(not set)");
   String profileProvince = flashStorage.getString("profile_province", "(not set)");
   String profileCity = flashStorage.getString("profile_city", "(not set)");
   String profileBarangay = flashStorage.getString("profile_barangay", "(not set)");
   String sosMessage = flashStorage.getString("sos_message", "(not set)");
   int profileCount = flashStorage.getInt("profile_saved_count", 0);
   int sosCount = flashStorage.getInt("sos_saved_count", 0);
   
   flashStorage.end();
   
   logEvent("FLASH", "   Profile - Name: " + profileName + ", Username: " + profileUsername);
   logEvent("FLASH", "   Profile - Street: " + profileStreet + ", Province: " + profileProvince);
   logEvent("FLASH", "   Profile - City: " + profileCity + ", Barangay: " + profileBarangay);
   logEvent("FLASH", "   Profile save count: " + String(profileCount));
   logEvent("FLASH", "   SOS message: \"" + sosMessage + "\"");
   logEvent("FLASH", "   SOS save count: " + String(sosCount));
   logEvent("FLASH", "✅ Verification complete");
 }

 // ----------------- Sync Command Handler -----------------
 void handleSyncCommand(String msg) {
   Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   Serial.println("🔵 [SYNC] ===== handleSyncCommand() CALLED =====");
   Serial.println("🔵 [SYNC] Raw message: " + msg);
   Serial.println("🔵 [SYNC] Message length: " + String(msg.length()) + " bytes");
   Serial.flush();
   
   logEvent("FLASH", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   logEvent("FLASH", "📨 RECEIVED SYNC COMMAND FROM PHONE");
   logEvent("FLASH", "   Raw message length: " + String(msg.length()) + " bytes");
   logEvent("FLASH", "   Raw message: " + msg);
   
   String command = extractJsonValue(msg, "command");
   Serial.println("🔵 [SYNC] Extracted command: \"" + command + "\"");
   Serial.flush();
   logEvent("FLASH", "   Extracted command: \"" + command + "\"");
   
   if (command == "sync_profile") {
     Serial.println("🔵 [SYNC] ✅ Command is 'sync_profile'");
     Serial.flush();
     logEvent("FLASH", "🔄 Processing profile sync command...");
     // Extract nested data object fields directly from main JSON
     String name = extractJsonValue(msg, "name");
     String username = extractJsonValue(msg, "username");
     String street = extractJsonValue(msg, "street");
     String province = extractJsonValue(msg, "province");
     String city = extractJsonValue(msg, "city");
     String barangay = extractJsonValue(msg, "barangay");
     
     Serial.println("🔵 [SYNC] Extracted profile values:");
     Serial.println("   name: \"" + name + "\"");
     Serial.println("   username: \"" + username + "\"");
     Serial.println("   street: \"" + street + "\"");
     Serial.println("   province: \"" + province + "\"");
     Serial.println("   city: \"" + city + "\"");
     Serial.println("   barangay: \"" + barangay + "\"");
     Serial.flush();
     
     logEvent("FLASH", "   Extracted values:");
     logEvent("FLASH", "     name: \"" + name + "\"");
     logEvent("FLASH", "     username: \"" + username + "\"");
     logEvent("FLASH", "     street: \"" + street + "\"");
     logEvent("FLASH", "     province: \"" + province + "\"");
     logEvent("FLASH", "     city: \"" + city + "\"");
     logEvent("FLASH", "     barangay: \"" + barangay + "\"");
     
     if (name.length() > 0 || username.length() > 0) {
       Serial.println("🔵 [SYNC] ✅ Valid profile data - calling saveProfileToFlash()");
       Serial.flush();
       logEvent("FLASH", "   ✅ Valid profile data - proceeding to save");
       saveProfileToFlash(name, username, street, province, city, barangay);
     } else {
       Serial.println("❌ [SYNC] Invalid profile data - missing name/username");
       Serial.flush();
       logEvent("FLASH_ERR", "❌ Invalid profile data - missing name/username");
       logEvent("FLASH_ERR", "   name.length()=" + String(name.length()) + ", username.length()=" + String(username.length()));
     }
   } else if (command == "sync_sos") {
     Serial.println("🔵 [SYNC] ✅ Command is 'sync_sos'");
     Serial.flush();
     logEvent("FLASH", "🔄 Processing SOS sync command...");
     String message = extractJsonValue(msg, "message");
     Serial.println("🔵 [SYNC] Extracted SOS message: \"" + message + "\"");
     Serial.println("🔵 [SYNC] Message length: " + String(message.length()) + " chars");
     Serial.flush();
     logEvent("FLASH", "   Extracted message: \"" + message + "\"");
     logEvent("FLASH", "   Message length: " + String(message.length()) + " characters");
     
     if (message.length() > 0) {
       Serial.println("🔵 [SYNC] ✅ Valid SOS message - calling saveSosToFlash()");
       Serial.flush();
       logEvent("FLASH", "   ✅ Valid SOS message - proceeding to save");
       saveSosToFlash(message);
     } else {
       Serial.println("❌ [SYNC] Invalid SOS message - empty");
       Serial.flush();
       logEvent("FLASH_ERR", "❌ Invalid SOS message format - empty message");
     }
   } else {
     Serial.println("❌ [SYNC] Unknown command: \"" + command + "\"");
     Serial.flush();
     logEvent("FLASH_ERR", "❌ Unknown sync command: \"" + command + "\"");
     logEvent("FLASH_ERR", "   Expected: sync_profile or sync_sos");
   }
   logEvent("FLASH", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
 }

 // ----------------- Setup -----------------
 void setup() {
   Serial.begin(115200);
   SerialBT.begin(BT_DEVICE_NAME);
   delay(800);
 
   logEvent("BOOT", "=== ESP32 Voice Bridge (Node A: nRF24 + SPP) ===");
   logEvent("BT", "Bluetooth Ready: " + String(BT_DEVICE_NAME));
   
   // Initialize flash storage and verify
   logEvent("FLASH", "🔧 Initializing flash storage...");
   flashStorage.begin("tulong", true); // Read-only to check
   int initProfileCount = flashStorage.getInt("profile_saved_count", 0);
   int initSosCount = flashStorage.getInt("sos_saved_count", 0);
   flashStorage.end();
   logEvent("FLASH", "   Existing profile count: " + String(initProfileCount));
   logEvent("FLASH", "   Existing SOS count: " + String(initSosCount));
   if (initProfileCount > 0 || initSosCount > 0) {
     verifyStoredData();
   }

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
 
   // Pipe directions for Node A: TX to Node B (address[1]), RX on address[0]
   radio.openWritingPipe(address[1]);    // send to Node B
   radio.openReadingPipe(1, address[0]); // receive on Node A's address
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
   if (millis() - lastDebug > 3000) { // every 1 second
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

     // Debug: Log all received Bluetooth messages
     Serial.println("🔵 [BT_RX] ========================================");
     Serial.println("🔵 [BT_RX] 📥 RECEIVED MESSAGE FROM PHONE");
     Serial.println("🔵 [BT_RX] Message: " + msg);
     Serial.println("🔵 [BT_RX] Length: " + String(msg.length()) + " bytes");
     Serial.flush();
     
     logEvent("BT_RX", "📥 Received from phone: " + msg);
     logEvent("BT_RX", "   Message length: " + String(msg.length()) + " bytes");

     // Check for sync commands (JSON format)
     bool hasCommand = msg.indexOf("\"command\":") >= 0;
     Serial.println("🔵 [BT_RX] Has 'command' field: " + String(hasCommand ? "YES" : "NO"));
     Serial.flush();
     
     if (hasCommand) {
       Serial.println("🔵 [BT_RX] ✅ SYNC COMMAND DETECTED - Routing to handleSyncCommand()");
       Serial.flush();
       logEvent("BT_RX", "   ✅ Sync command detected - routing to handleSyncCommand()");
       handleSyncCommand(msg);
       return;
     } else {
       Serial.println("🔵 [BT_RX] ⚠️ Not a sync command - continuing normal processing");
       Serial.flush();
     }

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
       SerialBT.println("<VOICE_READY>"); // <-- app can start streaming
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
      // logEvent("BT", "Voice chunk forwarded (" + String(msg.length()) + " chars)");
     } else {
     //  logEvent("BT_RX", "Text: " + msg);
       sendTextPacket(msg);
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
 