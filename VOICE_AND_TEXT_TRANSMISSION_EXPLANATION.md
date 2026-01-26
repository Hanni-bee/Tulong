# 🎤 Voice & Text Transmission Explanation

## 📋 System Architecture Overview

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│  Phone A    │         │  ESP32 A    │         │  ESP32 B    │         │  Phone B    │
│ (Flutter)   │◄───────►│  (Node A)   │◄───────►│  (Node B)   │◄───────►│ (Flutter)   │
└─────────────┘         └─────────────┘         └─────────────┘         └─────────────┘
     Bluetooth              nRF24L01 RF              nRF24L01 RF              Bluetooth
     SPP Serial             2.4GHz Radio            2.4GHz Radio             SPP Serial
```

---

## 🎤 VOICE DATA TRANSMISSION & RECEIVING

### **📤 TRANSMISSION FLOW (Phone A → Phone B)**

#### **1. Flutter App (Phone A) - Recording & Encoding**

**Location:** `lib/services/voice_chat_extension.dart`

**Process:**
1. **User presses record button** → `startRecording()` is called
2. **Audio Recording:**
   - Uses `FlutterSoundRecorder` with AAC codec
   - Sample rate: 44.1 kHz, Mono, 128 kbps bitrate
   - Records to temporary file: `voice_{timestamp}.aac`

3. **User releases button** → `stopRecordingAndSend()` is called
4. **Validation:**
   - Checks file size (minimum 1000 bytes)
   - Validates AAC format
   - Auto-retry if validation fails (up to 2 attempts)

5. **Base64 Encoding:**
   ```dart
   final base64Audio = await _voiceExtension.audioFileToBase64(recordingPath);
   ```
   - Converts AAC file to Base64 string
   - Uses parallel processing (`compute()`) for performance

6. **Sending to ESP32:**
   ```dart
   await sendVoiceMessage(base64Audio, (chunk) => _bluetoothService.sendMessage(chunk));
   ```
   - Sends `<VOICE_START>\n` marker
   - Sends Base64 string in **28-character chunks** (ESP32 packet size limit)
   - Each chunk sent with `\n` terminator
   - Sends `<VOICE_END>\n` marker when complete

#### **2. ESP32 (Node A) - Receiving from Bluetooth & Transmitting via RF**

**Location:** `esp32_node_A.ino` → `loop()` function

**Process:**
1. **Bluetooth Reception:**
   ```cpp
   if (SerialBT.available()) {
     String msg = SerialBT.readStringUntil('\n');
   ```
   - Reads line-by-line from Bluetooth Serial

2. **Voice Start Detection:**
   ```cpp
   if (msg == "<VOICE_START>") {
     if (channelBusy()) {
       SerialBT.println("<VOICE_DENY_BUSY>");
     } else {
       isVoice = true;
       txVoice = true;
       g_txSeq = 0;
       sendVoiceControl(VTYPE_START);  // Send RF START packet
       SerialBT.println("<VOICE_READY>");
     }
   }
   ```
   - Checks if RF channel is busy (another transmission active)
   - If not busy, sets voice transmission state
   - Sends `VTYPE_START` (0xD0) packet over nRF24L01

3. **Voice Data Transmission:**
   ```cpp
   if (isVoice) {
     sendVoiceLineWithSeq(msg);  // msg contains Base64 chunk
   }
   ```
   - **Packet Structure:**
     ```
     [VoiceHdr (4 bytes)] + [Payload (up to 28 bytes)]
     VoiceHdr:
       - type: VTYPE_DATA (0xD1)
       - seq: g_txSeq (increments per packet)
       - crc8: CRC-8 checksum over [type|seq|payload]
     ```
   - Chunks Base64 string into 28-byte packets
   - Each packet gets sequential number (`g_txSeq`)
   - CRC-8 computed for error detection
   - Sends via `sendRfRaw()` with retry logic (up to 7 seconds)

4. **Voice End:**
   ```cpp
   if (msg == "<VOICE_END>") {
     sendVoiceControl(VTYPE_END);  // Send RF END packet
     SerialBT.println("<VOICE_DONE>");
   }
   ```
   - Sends `VTYPE_END` (0xD2) packet
   - Cleans up transmission state

#### **3. ESP32 (Node B) - Receiving from RF & Forwarding to Bluetooth**

**Location:** `esp32_node_B.ino` → `handleRfPacket()` function

**Process:**
1. **RF Packet Reception:**
   ```cpp
   if (radio.available()) {
     handleRfPacket();
   }
   ```
   - nRF24L01 receives packet
   - Reads packet into buffer

2. **CRC Verification:**
   ```cpp
   const uint8_t crcExpect = crc8_hdr_payload(hdr->type, hdr->seq, payload, payLen);
   if (crcGot != crcExpect) {
     Serial.println("[RF_ERR] CRC mismatch, dropping packet");
     return;
   }
   ```
   - Verifies CRC-8 checksum
   - Drops packet if CRC mismatch

3. **Voice Start:**
   ```cpp
   if (hdr->type == VTYPE_START) {
     rxVoice = true;
     rxExpect = 0;
     incomingBuffer = "";
   }
   ```
   - Initializes voice reception state
   - Clears buffer
   - If currently transmitting, cancels own transmission

4. **Voice Data Reception:**
   ```cpp
   if (hdr->type == VTYPE_DATA) {
     if (seq != rxExpect) {
       // Packet loss detected
       rxExpect = seq + 1;
     } else {
       rxExpect++;
     }
     incomingBuffer += String((char*)payload, payLen);
   }
   ```
   - Checks sequence number for packet loss
   - Appends payload to `incomingBuffer`
   - Tracks expected sequence number

5. **Voice End:**
   ```cpp
   if (hdr->type == VTYPE_END) {
     rxVoice = false;
     SerialBT.println("<VOICE_START>");
     SerialBT.println(incomingBuffer);  // Full Base64 string
     SerialBT.println("<VOICE_END>");
     incomingBuffer = "";
   }
   ```
   - Sends complete Base64 string to phone via Bluetooth
   - Wraps with `<VOICE_START>` and `<VOICE_END>` markers

6. **Timeout Handling:**
   ```cpp
   if (rxVoice && (millis() - lastRxMillis > VOICE_TIMEOUT)) {
     // Assume transmission ended, flush buffer
   }
   ```
   - If no packets received for 3 seconds, assumes transmission ended
   - Flushes buffer to phone

#### **4. Flutter App (Phone B) - Receiving & Playback**

**Location:** `lib/services/voice_chat_extension.dart` → `processIncomingData()`

**Process:**
1. **Bluetooth Reception:**
   ```dart
   List<String> processIncomingData(String data) {
     if (trimmed == '<VOICE_START>') {
       _isReceivingVoice = true;
       _voiceBuffer.clear();
     }
   ```
   - Detects `<VOICE_START>` marker
   - Initializes voice buffer

2. **Data Accumulation:**
   ```dart
   if (_isReceivingVoice) {
     _voiceBuffer.write(trimmed);  // Append Base64 chunks
   }
   ```
   - Accumulates Base64 string chunks

3. **Voice End:**
   ```dart
   if (trimmed == '<VOICE_END>') {
     final full = _voiceBuffer.toString();
     messages.add('VOICE_MESSAGE:$full');
   }
   ```
   - Detects `<VOICE_END>` marker
   - Creates voice message object

4. **Playback:**
   ```dart
   Future<bool> playVoiceMessage(String base64Audio) async {
     final audioBytes = base64Decode(cleaned);
     // Write to temp file
     await _player.play(DeviceFileSource(_currentPlayingPath!));
   }
   ```
   - Decodes Base64 to binary
   - Writes to temporary AAC file
   - Plays using `AudioPlayer`

---

### **📥 RECEIVING FLOW (Phone B → Phone A)**

The receiving flow is **identical** but in reverse:
- Phone B records → ESP32 B transmits → ESP32 A receives → Phone A plays

---

## 💬 TEXT MESSAGE TRANSMISSION & RECEIVING

### **📤 TRANSMISSION FLOW (Phone A → Phone B)**

#### **1. Flutter App (Phone A) - Sending Text**

**Location:** `lib/providers/chat_provider.dart` → `sendMessage()`

**Process:**
1. **User types message and sends**
2. **Message Format:**
   ```dart
   _bluetoothService.sendMessage(textMessage);
   ```
   - Sends plain text string
   - No special formatting needed

#### **2. ESP32 (Node A) - Receiving & Transmitting**

**Location:** `esp32_node_A.ino` → `loop()` function

**Process:**
1. **Bluetooth Reception:**
   ```cpp
   if (SerialBT.available()) {
     String msg = SerialBT.readStringUntil('\n');
     if (!isVoice) {
       sendTextPacket(msg);  // Send as text
     }
   }
   ```
   - Reads text message from Bluetooth
   - Only processes if not in voice mode

2. **Text Packet Transmission:**
   ```cpp
   bool sendTextPacket(const String &msg) {
     for (int i = 0; i < N; i += 28) {
       // Create packet with TTYPE_TEXT (0xA0)
       hdr->type = TTYPE_TEXT;
       hdr->seq = (uint16_t)(i / 28);
       // Compute CRC
       hdr->crc8 = crc8_hdr_payload(...);
       sendRfRaw(buf, sizeof(VoiceHdr) + L);
     }
   }
   ```
   - **Packet Structure:**
     ```
     [VoiceHdr (4 bytes)] + [Text Payload (up to 28 bytes)]
     VoiceHdr:
       - type: TTYPE_TEXT (0xA0)
       - seq: chunk number (0, 1, 2, ...)
       - crc8: CRC-8 checksum
     ```
   - Splits long messages into 28-byte chunks
   - Each chunk numbered sequentially
   - Sends via nRF24L01

#### **3. ESP32 (Node B) - Receiving & Reassembling**

**Location:** `esp32_node_B.ino` → `handleRfPacket()` function

**Process:**
1. **Text Packet Reception:**
   ```cpp
   if (hdr->type == TTYPE_TEXT) {
     if (!rxText) {
       rxText = true;
       textBuffer = "";
       textExpect = seq + 1;
     }
     textBuffer += String((char*)payload, payLen);
     lastTextPacketTime = millis();
   }
   ```
   - Detects `TTYPE_TEXT` packets
   - Accumulates chunks into `textBuffer`
   - Tracks last packet time for timeout

2. **Timeout & Reassembly:**
   ```cpp
   if (rxText && (millis() - lastTextPacketTime > TEXT_TIMEOUT_MS)) {
     // 900ms timeout - message complete
     if (textBuffer.startsWith("<MSG_START:")) {
       // Pass through existing header
       SerialBT.println(header);
       SerialBT.println(body);
       SerialBT.println("<MSG_END>");
     } else {
       // Generate new header with UID
       String header = String("<MSG_START:") + myUid + ">";
       SerialBT.println(header);
       SerialBT.println(textBuffer);
       SerialBT.println("<MSG_END>");
     }
   }
   ```
   - After 900ms of no packets, assumes message complete
   - **Header Handling:**
     - If message already has `<MSG_START:UID>`, passes it through (for SOS messages)
     - Otherwise, generates new header with receiver's UID
   - Sends to phone with `<MSG_START:UID>`, body, and `<MSG_END>`

#### **4. Flutter App (Phone B) - Receiving Text**

**Location:** `lib/providers/chat_provider.dart` → `_processIncomingMessage()`

**Process:**
1. **Message Parsing:**
   ```dart
   if (message.startsWith('<MSG_START:')) {
     // Extract UID and message body
     final uid = extractUID(message);
     final body = extractBody(message);
     _addMessage(body, isMe: false, senderName: uid);
   }
   ```
   - Parses `<MSG_START:UID>` header
   - Extracts sender UID
   - Displays message in chat

---

## 🔑 Key Technical Details

### **Packet Structure**

All packets use the same header format:
```cpp
struct VoiceHdr {
  uint8_t  type;    // Packet type (VTYPE_START, VTYPE_DATA, VTYPE_END, TTYPE_TEXT, etc.)
  uint16_t seq;     // Sequence number (little-endian)
  uint8_t  crc8;    // CRC-8 checksum
};
```

**Packet Types:**
- `VTYPE_START` (0xD0): Voice transmission start
- `VTYPE_DATA` (0xD1): Voice data chunk
- `VTYPE_END` (0xD2): Voice transmission end
- `TTYPE_TEXT` (0xA0): Text message chunk
- `PTYPE_REQ` (0xB0): Profile request
- `PTYPE_RESP` (0xB1): Profile response

### **CRC-8 Checksum**

- **Polynomial:** 0x07
- **Initial Value:** 0x00
- **Computed over:** `[type | seq_low | seq_high | payload]`
- **Excludes:** CRC field itself

### **Chunking Strategy**

- **Maximum payload:** 28 bytes per packet (nRF24L01 limit: 32 bytes - 4 byte header)
- **Voice:** Base64 string split into 28-char chunks
- **Text:** Plain text split into 28-byte chunks
- **Sequence numbers:** Increment per chunk

### **Error Handling**

1. **CRC Mismatch:** Packet dropped, logged
2. **Sequence Loss:** Detected, logged, receiver resyncs
3. **Timeout:** 
   - Voice: 3 seconds → flush buffer
   - Text: 900ms → assume message complete
4. **Channel Busy:** Voice transmission denied with `<VOICE_DENY_BUSY>`

### **State Management**

**ESP32 Voice States:**
- `isVoice`: Currently in voice mode (from phone)
- `txVoice`: Currently transmitting voice (RF)
- `rxVoice`: Currently receiving voice (RF)
- `g_txSeq`: Transmit sequence counter
- `rxExpect`: Expected receive sequence number

**ESP32 Text States:**
- `rxText`: Currently receiving text message
- `textBuffer`: Accumulated text chunks
- `textExpect`: Expected next sequence number

---

## 📊 Data Flow Summary

### **Voice Message:**
```
Phone A → [AAC Record] → [Base64 Encode] → [28-char chunks] → 
ESP32 A → [RF Packets: START + DATA*N + END] → 
ESP32 B → [Reassemble Base64] → [Send to Phone] → 
Phone B → [Base64 Decode] → [AAC File] → [Play Audio]
```

### **Text Message:**
```
Phone A → [Plain Text] → 
ESP32 A → [RF Packets: TEXT*N] → 
ESP32 B → [Reassemble Text] → [Add Header] → 
Phone B → [Parse Header] → [Display Message]
```

---

## 🔧 Configuration

**nRF24L01 Settings:**
- Channel: 108
- Data Rate: 250 kbps
- Power Level: LOW
- Auto ACK: Enabled
- Dynamic Payloads: Enabled

**Bluetooth:**
- Protocol: SPP (Serial Port Profile)
- Node A: `ESP32_NodeA_VoiceAC`
- Node B: `ESP32_NodeB_VoiceAC`

**Timeouts:**
- Voice RF timeout: 3000ms
- Text reassembly timeout: 900ms
- Profile response timeout: 1200ms

---

## 🎯 Special Features

### **SOS Button**
- Hardware button on GPIO4
- Sends pre-configured SOS message from flash
- Format: `<MSG_START:UIDSOS>` + message + `<MSG_END>`
- Uses continuous sequence numbers across frame

### **Profile Request/Response**
- Request format: `REQ|<reqId>|<destUid>|<targetUid>`
- Response format: `RSP|<reqId>|<destUid>|{JSON}`
- Only requesting node processes response (destUid filter)

---

## 📝 Notes

1. **Broadcast Nature:** RF is effectively broadcast, but filtering happens at application level (destUid matching)
2. **Sequence Numbers:** Continuous across entire message for proper reassembly
3. **Header Preservation:** If sender includes `<MSG_START:UID>`, receiver passes it through (important for SOS tagging)
4. **Channel Busy Detection:** Prevents voice collisions by checking carrier, receiving state, and recent transmission
