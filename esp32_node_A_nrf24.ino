/*
 * ESP32 NODE A - NRF24L01 WITH BASE64 VOICE MESSAGES + MISSING PACKET RETRANSMISSION
 * Compatible with ESP32 core v3.3.2+
 * Bidirectional communication for text and voice messages
 * Voice messages: PCM -> Base64 -> Chunked -> nRF24L01 -> Reassemble -> Base64 -> PCM
 */

#include <BluetoothSerial.h>
#include <SPI.h>
#include <nRF24L01.h>
#include <RF24.h>
#include "esp_bt.h"
#include "esp_bt_main.h"
#include "esp_bt_device.h"
#include "esp_spp_api.h"

// ---------------- CONFIG ----------------
#define CE_PIN 26
#define CSN_PIN 27
#define NRF24_PAYLOAD_SIZE 32
#define NRF24_DATA_SIZE (NRF24_PAYLOAD_SIZE - 8)  // 24 bytes per chunk
#define BT_DEVICE_NAME "ESP32_Node_A"
#define MAX_CHUNKS 255  // Support up to 255 chunks for large Base64 strings (~6KB)
#define BUFFER_SIZE 6144  // 6KB buffer for Base64 strings
// ----------------------------------------

BluetoothSerial BT;
RF24 radio(CE_PIN, CSN_PIN);

const byte address[][6] = {"1Node", "2Node"};
const byte thisNode = 0;
const byte otherNode = 1;

String nId = "";
String buf = "";
bool conn = false;

struct ChunkHeader {
  uint32_t msgId;
  uint8_t chunkIndex;
  uint8_t totalChunks;
  uint8_t dataLen;
  uint8_t msgType;  // 0 = text, 1 = voice (Base64)
};

// Receiving chunks structure with missing packet tracking
uint32_t receivingMsgId = 0;
uint8_t receivingChunks[MAX_CHUNKS];  // 0 = not received, 1 = received
uint8_t chunkData[MAX_CHUNKS][NRF24_DATA_SIZE];
uint8_t chunkLengths[MAX_CHUNKS];
uint8_t receivedChunkCount = 0;
uint8_t expectedTotalChunks = 0;
bool isReceiving = false;
uint8_t receivingMsgType = 0;  // 0 = text, 1 = voice
uint32_t messageCounter = 0;
unsigned long lastChunkTime = 0;
unsigned long reassemblyTimeout = 5000;  // 5 seconds timeout

// Missing packet request tracking
bool waitingForRetransmission = false;
uint8_t missingChunksList[MAX_CHUNKS];
uint8_t missingChunksCount = 0;
unsigned long retransmissionRequestTime = 0;

// --- Forward declarations ---
void handleBluetooth();
void processBluetoothMessage(String msg);
void sendViaNRF24(String message, uint8_t msgType);
void handleNRF24();
void sendStatus();
void forwardMessageToPhone(String message);
void requestMissingChunks(uint32_t msgId, uint8_t* missingList, uint8_t count);
String extractJsonValue(String json, String key);

void setup() {
  delay(2000);
  Serial.begin(115200);
  delay(200);
  
  uint64_t c = ESP.getEfuseMac();
  nId = "NodeA_" + String((uint32_t)(c >> 32), HEX);
  nId.toUpperCase();
  
  Serial.println("\n=== ESP32 NODE A START ===");
  Serial.println("Node ID: " + nId);
  
  // Init SPI for NRF24L01
  SPI.begin(18, 19, 23, -1);
  
  if (!radio.begin()) {
    Serial.println("[ERROR] NRF24L01 init failed!");
    while (1) delay(1000);
  }
  
  radio.setPALevel(RF24_PA_MAX);
  radio.setDataRate(RF24_250KBPS);
  radio.setChannel(76);
  radio.setAutoAck(true);
  radio.setRetries(15, 15);
  radio.setCRCLength(RF24_CRC_16);
  radio.openReadingPipe(thisNode, address[thisNode]);
  radio.startListening();
  
  Serial.println("[OK] NRF24 ready.");
  
  // Bluetooth init
  esp_spp_deinit();
  delay(100);
  if (!BT.begin(BT_DEVICE_NAME, true)) {
    Serial.println("[ERROR] BT init failed!");
    while (1) delay(1000);
  }
  esp_spp_start_srv(ESP_SPP_SEC_NONE, ESP_SPP_ROLE_SLAVE, 2, "SPP_NODE_A");
  BT.enableSSP();
  BT.setPin("1234", 4);
  
  Serial.println("[OK] Bluetooth started as: " + String(BT_DEVICE_NAME));
  Serial.println("[READY] Waiting for phone connection...\n");
}

void loop() {
  bool hasClient = BT.hasClient();
  
  if (hasClient) {
    if (!conn) {
      conn = true;
      Serial.println("\n[BT] ✓ Client connected");
      sendStatus();
    }
    handleBluetooth();
  } else if (conn) {
    conn = false;
    Serial.println("\n[BT] ✗ Client disconnected");
    buf = "";
  }
  
  handleNRF24();
  
  // Check for missing chunks timeout
  if (isReceiving && (millis() - lastChunkTime > 2000) && receivedChunkCount < expectedTotalChunks) {
    // Check for missing chunks and request retransmission
    missingChunksCount = 0;
    for (uint8_t i = 0; i < expectedTotalChunks; i++) {
      if (receivingChunks[i] == 0) {
        missingChunksList[missingChunksCount++] = i;
      }
    }
    
    if (missingChunksCount > 0 && !waitingForRetransmission) {
      Serial.println("[NRF24 RX] ⚠ Missing " + String(missingChunksCount) + " chunks, requesting retransmission...");
      requestMissingChunks(receivingMsgId, missingChunksList, missingChunksCount);
      waitingForRetransmission = true;
      retransmissionRequestTime = millis();
    }
  }
  
  // Reset retransmission flag after timeout
  if (waitingForRetransmission && (millis() - retransmissionRequestTime > 3000)) {
    waitingForRetransmission = false;
  }
  
  delay(10);
}

void handleBluetooth() {
  if (BT.available() > 0) {
    // Read text message line by line (JSON format)
    while (BT.available()) {
      char c = BT.read();
      if (c == '\n' || c == '\r') {
        if (buf.length() > 0) {
          Serial.println("[BT] ✓✓✓ COMPLETE MESSAGE RECEIVED FROM PHONE! ✓✓✓");
          Serial.println("[BT] Buffer length: " + String(buf.length()) + " characters");
          processBluetoothMessage(buf);
          buf = "";
        }
      } else if (buf.length() < BUFFER_SIZE) {  // Increased buffer for Base64
        buf += c;
        if (buf.length() == 1) {
          Serial.println("[BT] 📥 Started receiving message from phone...");
        }
      } else {
        Serial.println("[BT] ⚠ Buffer overflow! Clearing...");
        buf = "";
      }
    }
  }
}

String extractJsonValue(String json, String key) {
  // Simple JSON value extraction without library
  String searchKey = "\"" + key + "\"";
  int keyPos = json.indexOf(searchKey);
  if (keyPos < 0) return "";
  
  int colonPos = json.indexOf(":", keyPos);
  if (colonPos < 0) return "";
  
  int startPos = colonPos + 1;
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

void processBluetoothMessage(String msg) {
  Serial.println("\n==========================================");
  Serial.println("[BT RX] ✓✓✓ MESSAGE FROM PHONE RECEIVED ✓✓✓");
  Serial.println("==========================================");
  Serial.println("[BT RX] Message length: " + String(msg.length()) + " bytes");
  Serial.println("[BT RX] Raw message: " + msg);
  
  // Check if message contains "type" field
  String msgType = extractJsonValue(msg, "type");
  Serial.println("[BT RX] Extracted message type: '" + msgType + "'");
  
  // Check for "message" field (indicates chat message)
  bool hasMessageField = msg.indexOf("\"message\":") >= 0;
  Serial.println("[BT RX] Has 'message' field: " + String(hasMessageField ? "YES" : "NO"));
  
  // Filter out system messages - only forward chat messages (text/voice/group/private)
  // System messages: status, auth, connected_users, request should NOT be forwarded via nRF24L01
  if (msgType == "status" || msgType == "auth" || msgType == "connected_users" || msgType == "request" ||
      msg.indexOf("\"status\":") >= 0 || msg.indexOf("\"auth\":") >= 0 || msg.indexOf("\"request\":") >= 0) {
    Serial.println("[BT RX] ⚠ System message detected - NOT forwarding via nRF24L01");
    Serial.println("[BT RX] Message type: " + msgType);
    Serial.println("==========================================\n");
    return;  // Don't forward system messages
  }
  
  if (msgType == "voice") {
    Serial.println("[BT RX] 🎤 Voice message (Base64) detected");
    // Voice message contains Base64 encoded AAC data
    String base64Data = extractJsonValue(msg, "voice_data");
    if (base64Data.length() > 0) {
      // Extract other fields
      String senderName = extractJsonValue(msg, "sender_name");
      String senderId = extractJsonValue(msg, "sender_id");
      String timestamp = extractJsonValue(msg, "timestamp");
      String duration = extractJsonValue(msg, "duration");
      String fileSize = extractJsonValue(msg, "fileSize");
      
      // Create full message with Base64 data
      String fullMsg = "{\"type\":\"voice\",\"voice_data\":\"" + base64Data + 
                       "\",\"sender_name\":\"" + senderName + 
                       "\",\"sender_id\":\"" + senderId + 
                       "\",\"timestamp\":\"" + timestamp + 
                       "\",\"duration\":\"" + duration + 
                       "\",\"fileSize\":\"" + fileSize + 
                       "\",\"from_node\":\"" + nId + "\"}";
      Serial.println("[BT->NRF24] Voice message length: " + String(fullMsg.length()) + " bytes");
      Serial.println("[BT->NRF24] Base64 data length: " + String(base64Data.length()) + " chars");
      sendViaNRF24(fullMsg, 1);  // msgType = 1 for voice
    } else {
      Serial.println("[BT RX] ⚠ Voice message has no voice_data field!");
    }
  } else if (msgType == "text" || msgType == "group" || msgType == "private") {
    // Text message (group or private) - explicit type match
    Serial.println("[BT RX] ✓ Text message detected (type: " + msgType + ")");
    String fullMsg = msg;
    if (fullMsg.endsWith("}")) {
      fullMsg.remove(fullMsg.length() - 1);
      fullMsg += ",\"from_node\":\"" + nId + "\"}";
    } else {
      fullMsg += ",\"from_node\":\"" + nId + "\"}";
    }
    Serial.println("[BT->NRF24] Forwarding text message via nRF24L01...");
    sendViaNRF24(fullMsg, 0);  // msgType = 0 for text
  } else if (hasMessageField && msgType.length() == 0) {
    // Message has "message" field but no explicit type - treat as text message
    Serial.println("[BT RX] ✓ Text message detected (has 'message' field, no explicit type)");
    String fullMsg = msg;
    if (fullMsg.endsWith("}")) {
      fullMsg.remove(fullMsg.length() - 1);
      fullMsg += ",\"type\":\"text\",\"from_node\":\"" + nId + "\"}";
    } else {
      fullMsg += ",\"type\":\"text\",\"from_node\":\"" + nId + "\"}";
    }
    Serial.println("[BT->NRF24] Forwarding text message via nRF24L01...");
    sendViaNRF24(fullMsg, 0);  // msgType = 0 for text
  } else {
    // Unknown message type - don't forward
    Serial.println("[BT RX] ⚠ Unknown message type: '" + msgType + "' - NOT forwarding");
    Serial.println("[BT RX] Message preview: " + msg.substring(0, min(100, (int)msg.length())));
  }
  Serial.println("==========================================\n");
}

void sendViaNRF24(String message, uint8_t msgType) {
  Serial.println("[NRF24 TX] Preparing to send " + String(msgType == 1 ? "voice" : "text") + " message...");
  
  // Convert message to bytes
  int msgLen = message.length();
  
  // Calculate number of chunks needed
  uint8_t totalChunks = (msgLen + NRF24_DATA_SIZE - 1) / NRF24_DATA_SIZE;
  
  if (totalChunks > MAX_CHUNKS) {
    Serial.println("[ERROR] Message too long! Max chunks: " + String(MAX_CHUNKS) + ", needed: " + String(totalChunks));
    return;
  }
  
  // Generate unique message ID
  uint32_t msgId = ++messageCounter;
  
  Serial.println("[NRF24 TX] Message ID: " + String(msgId) + ", Length: " + String(msgLen) + " bytes, Chunks: " + String(totalChunks));
  
  // Stop listening to transmit
  radio.stopListening();
  radio.openWritingPipe(address[otherNode]);
  
  // Send each chunk slowly - "slowly but surely"
  bool allSent = true;
  for (uint8_t i = 0; i < totalChunks; i++) {
    uint8_t chunk[NRF24_PAYLOAD_SIZE] = {0};
    ChunkHeader* header = (ChunkHeader*)chunk;
    
    // Fill header
    header->msgId = msgId;
    header->chunkIndex = i;
    header->totalChunks = totalChunks;
    header->msgType = msgType;
    
    // Calculate data start and length for this chunk
    int start = i * NRF24_DATA_SIZE;
    int len = min(NRF24_DATA_SIZE, msgLen - start);
    header->dataLen = len;
    
    // Copy data
    const char* msgPtr = message.c_str();
    memcpy(chunk + sizeof(ChunkHeader), msgPtr + start, len);
    
    // Send chunk with retries
    bool sent = false;
    for (int retry = 0; retry < 5 && !sent; retry++) {
      sent = radio.write(&chunk, NRF24_PAYLOAD_SIZE);
      if (!sent && retry < 4) {
        delay(10);
      }
    }
    
    if (sent) {
      Serial.println("[OK] Chunk " + String(i + 1) + "/" + String(totalChunks) + " (" + String(len) + " bytes)");
    } else {
      Serial.println("[FAIL] Chunk " + String(i + 1) + "/" + String(totalChunks) + " (retried 5x)");
      allSent = false;
    }
    
    delay(50);  // Slow transmission - "slowly but surely"
  }
  
  // Resume listening
  radio.startListening();
  
  if (allSent) {
    Serial.println("[NRF24 TX] All chunks sent successfully.\n");
  } else {
    Serial.println("[NRF24 TX] Some chunks failed to send.\n");
  }
}

void handleNRF24() {
  if (radio.available()) {
    uint8_t chunk[NRF24_PAYLOAD_SIZE] = {0};
    radio.read(&chunk, NRF24_PAYLOAD_SIZE);
    
    ChunkHeader* header = (ChunkHeader*)chunk;
    uint32_t msgId = header->msgId;
    uint8_t idx = header->chunkIndex;
    uint8_t total = header->totalChunks;
    uint8_t len = header->dataLen;
    uint8_t msgType = header->msgType;
    
    // Check if it's a retransmission request (special msgId = 0xFFFFFFFF)
    if (msgId == 0xFFFFFFFF && msgType == 0xFF) {
      // This is a retransmission request
      // Format: [0xFFFFFFFF][chunk_index][total_chunks][requested_msg_id(4 bytes in data)]
      uint32_t requestedMsgId = 0;
      if (len >= 4) {
        uint8_t* data = chunk + sizeof(ChunkHeader);
        requestedMsgId = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
      }
      Serial.println("[NRF24 RX] Retransmission request for msgId: " + String(requestedMsgId) + ", chunk: " + String(idx));
      // Note: We don't store sent messages, so we can't retransmit
      // In a real implementation, you'd need to store sent messages temporarily
      return;
    }
    
    // Validate chunk data
    if (idx >= MAX_CHUNKS || total > MAX_CHUNKS || total == 0 || len > NRF24_DATA_SIZE || len == 0) {
      Serial.println("[ERROR] Invalid chunk header! idx=" + String(idx) + " total=" + String(total) + " len=" + String(len));
      return;
    }
    
    Serial.print("[NRF24 RX] Chunk " + String(idx + 1) + "/" + String(total) + " (ID: " + String(msgId) + ", Type: " + String(msgType == 1 ? "voice" : "text") + ")");
    
    // Check if new message or continuing
    if (!isReceiving || receivingMsgId != msgId) {
      // New message - initialize
      receivingMsgId = msgId;
      expectedTotalChunks = total;
      receivedChunkCount = 0;
      isReceiving = true;
      receivingMsgType = msgType;
      waitingForRetransmission = false;
      memset(receivingChunks, 0, MAX_CHUNKS);
      memset(chunkLengths, 0, MAX_CHUNKS);
      lastChunkTime = millis();
      Serial.println(" - New " + String(msgType == 1 ? "voice" : "text") + " message started.");
    } else {
      Serial.println(" - Continuing message.");
      lastChunkTime = millis();
    }
    
    // Store chunk data (only if not already received)
    if (idx < MAX_CHUNKS && receivingChunks[idx] == 0) {
      uint8_t* data = chunk + sizeof(ChunkHeader);
      
      if (len > 0 && len <= NRF24_DATA_SIZE) {
        memcpy(chunkData[idx], data, len);
        chunkLengths[idx] = len;
        receivingChunks[idx] = 1;
        receivedChunkCount++;
        
        Serial.println("[NRF24 RX] ✓ Stored chunk " + String(idx + 1) + " (Total: " + String(receivedChunkCount) + "/" + String(expectedTotalChunks) + ")");
      }
    } else if (idx < MAX_CHUNKS && receivingChunks[idx] == 1) {
      Serial.println("[NRF24 RX] ⚠ Duplicate chunk " + String(idx + 1) + " ignored.");
    }
    
    // Check if all chunks received
    bool allChunksReceived = true;
    if (isReceiving && receivedChunkCount >= expectedTotalChunks) {
      for (uint8_t i = 0; i < expectedTotalChunks; i++) {
        if (receivingChunks[i] == 0) {
          allChunksReceived = false;
          break;
        }
      }
    } else {
      allChunksReceived = false;
    }
    
    // Reassemble if all chunks are present
    if (isReceiving && allChunksReceived) {
      Serial.println("\n==========================================");
      Serial.println("[NRF24 RX] ✓✓✓ ALL CHUNKS RECEIVED ✓✓✓");
      Serial.println("==========================================");
      Serial.println("[NRF24 RX] Message type: " + String(receivingMsgType == 1 ? "VOICE" : "TEXT"));
      
      // Reassemble message
      String receivingMessage = "";
      for (uint8_t i = 0; i < expectedTotalChunks; i++) {
        if (receivingChunks[i] == 1 && chunkLengths[i] > 0) {
          for (int j = 0; j < chunkLengths[i]; j++) {
            char c = (char)chunkData[i][j];
            if (c != 0) {
              receivingMessage += c;
            }
          }
        }
      }
      
      Serial.println("[NRF24 RX] ✓ Reassembly complete!");
      Serial.println("[NRF24 RX] Total length: " + String(receivingMessage.length()) + " bytes");
      Serial.println("[NRF24 RX] Preparing to forward to phone...");
      Serial.println("==========================================");
      
      // Forward to Bluetooth
      if (receivingMessage.length() > 0) {
        forwardMessageToPhone(receivingMessage);
      }
      
      // Reset for next message
      isReceiving = false;
      receivedChunkCount = 0;
      waitingForRetransmission = false;
      memset(receivingChunks, 0, MAX_CHUNKS);
      memset(chunkLengths, 0, MAX_CHUNKS);
    }
  }
}

void requestMissingChunks(uint32_t msgId, uint8_t* missingList, uint8_t count) {
  Serial.println("[NRF24 TX] Requesting " + String(count) + " missing chunks for msgId: " + String(msgId));
  
  // Send retransmission request for each missing chunk
  radio.stopListening();
  radio.openWritingPipe(address[otherNode]);
  
  for (uint8_t i = 0; i < count && i < 10; i++) {  // Request max 10 at a time
    uint8_t chunk[NRF24_PAYLOAD_SIZE] = {0};
    ChunkHeader* header = (ChunkHeader*)chunk;
    
    header->msgId = 0xFFFFFFFF;  // Special ID for retransmission request
    header->chunkIndex = missingList[i];
    header->totalChunks = 0;
    header->msgType = 0xFF;  // Special type for request
    header->dataLen = 4;  // Store requested msgId in data
    
    uint8_t* data = chunk + sizeof(ChunkHeader);
    data[0] = (uint8_t)(msgId & 0xFF);
    data[1] = (uint8_t)((msgId >> 8) & 0xFF);
    data[2] = (uint8_t)((msgId >> 16) & 0xFF);
    data[3] = (uint8_t)((msgId >> 24) & 0xFF);
    
    radio.write(&chunk, NRF24_PAYLOAD_SIZE);
    delay(20);
  }
  
  radio.startListening();
}

void forwardMessageToPhone(String message) {
  if (conn && BT.hasClient()) {
    Serial.println("[BT TX] Forwarding message to phone (" + String(message.length()) + " bytes)...");
    BT.println(message);
    Serial.println("[BT TX] ✓ Message sent to phone.\n");
  } else {
    Serial.println("[BT TX] ✗ Cannot send - no connection.\n");
  }
}

void sendStatus() {
  String status = "{\"status\":\"connected\",\"node_id\":\"" + nId + "\"}";
  BT.println(status);
  Serial.println("[STATUS] Sent to phone.");
}

