/*
 * ESP32 NODE A - NRF24L01 WITH BINARY CHUNKING + FULL LOGGING
 * Compatible with ESP32 core v3.3.2+
 * Fixed: Proper chunk reassembly and message forwarding
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
#define NRF24_DATA_SIZE (NRF24_PAYLOAD_SIZE - 8)
#define BT_DEVICE_NAME "ESP32_Node_A"
// ----------------------------------------

BluetoothSerial BT;
RF24 radio(CE_PIN, CSN_PIN);

const byte address[][6] = {"1Node", "2Node"};
const byte thisNode = 0;
const byte otherNode = 1;

String nId = "";
String buf = "";
bool conn = false;

// Phone binary chunking variables (for messages > 128 bytes)
uint8_t phoneChunkBuffer[512];  // Store received phone chunks
uint8_t phoneChunkData[4][128];  // Store up to 4 chunks from phone (128 bytes each)
uint8_t phoneChunkLengths[4];
uint8_t phoneReceivedChunks = 0;
uint8_t phoneExpectedChunks = 0;
uint32_t phoneMsgId = 0;
bool isReceivingPhoneChunks = false;

struct ChunkHeader {
  uint32_t msgId;
  uint8_t chunkIndex;
  uint8_t totalChunks;
  uint8_t dataLen;
  uint8_t reserved;
};

// Receiving chunks structure - store chunks by index for proper reassembly
uint32_t receivingMsgId = 0;
uint8_t receivingChunks[32];  // Track which chunks received (0 = not received, 1 = received)
uint8_t chunkData[32][NRF24_DATA_SIZE];  // Store chunk data by index
uint8_t chunkLengths[32];  // Store length of each chunk
uint8_t receivedChunkCount = 0;
uint8_t expectedTotalChunks = 0;
bool isReceiving = false;
uint32_t messageCounter = 0;

// --- Forward declarations ---
void handleBluetooth();
void handlePhoneBinaryChunk();
void processBluetoothMessage(String msg);
void sendViaNRF24(String message);
void handleNRF24();
void sendStatus();
void forwardMessageToPhone(String message);

void setup() {
  delay(500);
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
  esp_spp_start_srv(ESP_SPP_SEC_NONE, ESP_SPP_ROLE_SLAVE, 1, "SPP_NODE_A");
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
  delay(10);
}

// ---------------- MAIN FUNCTIONS ----------------

void handleBluetooth() {
  if (BT.available() > 0) {
    uint8_t availableBytes = BT.available();
    Serial.println("[BT] 📱 Data available from phone: " + String(availableBytes) + " bytes");
    
    // Peek at first byte to determine if it's binary chunk or text
    uint8_t firstByte = BT.peek();
    
    // Check if it's a binary chunk (0x01 = first, 0x02 = middle, 0x03 = last)
    if (firstByte == 0x01 || firstByte == 0x02 || firstByte == 0x03) {
      Serial.println("[BT] 📦 Binary chunk detected (Type: 0x" + String(firstByte, HEX) + ")");
      handlePhoneBinaryChunk();
    } else {
      // Text message - read character by character until newline
      while (BT.available()) {
        char c = BT.read();
        if (c == '\n' || c == '\r') {
          if (buf.length() > 0) {
            Serial.println("[BT] ✓✓✓ COMPLETE TEXT MESSAGE RECEIVED FROM PHONE! ✓✓✓");
            Serial.println("[BT] Buffer length: " + String(buf.length()) + " characters");
            processBluetoothMessage(buf);
            buf = "";
          }
        } else if (buf.length() < 512) {
          buf += c;
          if (buf.length() == 1) {
            Serial.println("[BT] 📥 Started receiving text message from phone...");
          }
        } else {
          Serial.println("[BT] ⚠ Buffer overflow! Clearing...");
          buf = "";  // Clear on overflow
        }
      }
    }
  }
}

void handlePhoneBinaryChunk() {
  // Phone chunk format: [TYPE(1)][MSG_ID(4)][CHUNK_INDEX(2)][TOTAL_CHUNKS(2)][DATA_LEN(2)][DATA...]
  if (BT.available() < 11) {  // Need at least 11 bytes for header
    Serial.println("[BT] ⚠ Not enough data for chunk header, waiting...");
    return;
  }
  
  uint8_t chunkType = BT.read();  // 0x01=first, 0x02=middle, 0x03=last
  
  // Read message ID (4 bytes, little-endian)
  uint32_t msgId = 0;
  msgId |= BT.read();
  msgId |= ((uint32_t)BT.read()) << 8;
  msgId |= ((uint32_t)BT.read()) << 16;
  msgId |= ((uint32_t)BT.read()) << 24;
  
  // Read chunk index (2 bytes, little-endian)
  uint16_t chunkIndex = BT.read();
  chunkIndex |= ((uint16_t)BT.read()) << 8;
  
  // Read total chunks (2 bytes, little-endian)
  uint16_t totalChunks = BT.read();
  totalChunks |= ((uint16_t)BT.read()) << 8;
  
  // Read data length (2 bytes, little-endian)
  uint16_t dataLen = BT.read();
  dataLen |= ((uint16_t)BT.read()) << 8;
  
  Serial.println("[BT] 📦 Binary chunk received - Type: 0x" + String(chunkType, HEX) + 
                 ", ID: " + String(msgId) + 
                 ", Index: " + String(chunkIndex + 1) + "/" + String(totalChunks) + 
                 ", Len: " + String(dataLen));
  
  // Check if new message
  if (!isReceivingPhoneChunks || phoneMsgId != msgId) {
    phoneMsgId = msgId;
    phoneExpectedChunks = totalChunks;
    phoneReceivedChunks = 0;
    isReceivingPhoneChunks = true;
    memset(phoneChunkData, 0, sizeof(phoneChunkData));
    memset(phoneChunkLengths, 0, sizeof(phoneChunkLengths));
    Serial.println("[BT] 📦 New binary message stream started (" + String(totalChunks) + " chunks)");
  }
  
  // Validate chunk index
  if (chunkIndex < 4 && dataLen <= 128) {
    // Check if we already have this chunk
    if (phoneChunkLengths[chunkIndex] > 0) {
      Serial.println("[BT] ⚠ Duplicate phone chunk " + String(chunkIndex + 1) + " ignored, skipping data...");
      // Skip the data bytes
      for (uint16_t i = 0; i < dataLen && BT.available(); i++) {
        BT.read();
      }
    } else {
      // Read data
      uint8_t* chunkPtr = phoneChunkData[chunkIndex];
      for (uint16_t i = 0; i < dataLen && BT.available(); i++) {
        chunkPtr[i] = BT.read();
      }
      phoneChunkLengths[chunkIndex] = dataLen;
      phoneReceivedChunks++;
      
      Serial.println("[BT] ✓ Stored phone chunk " + String(chunkIndex + 1) + 
                     " (Total: " + String(phoneReceivedChunks) + "/" + String(phoneExpectedChunks) + ")");
    }
    
    // Check if all chunks received (verify by checking all chunks are present, not just count)
    bool allPhoneChunksReceived = (phoneReceivedChunks >= phoneExpectedChunks);
    if (allPhoneChunksReceived) {
      // Double-check all chunks are present
      for (uint8_t i = 0; i < phoneExpectedChunks; i++) {
        if (phoneChunkLengths[i] == 0) {
          allPhoneChunksReceived = false;
          Serial.println("[BT] ⚠ Missing phone chunk " + String(i + 1) + ", waiting...");
          break;
        }
      }
    }
    
    if (allPhoneChunksReceived) {
      // Reassemble complete message
      String completeMessage = "";
      for (uint8_t i = 0; i < phoneExpectedChunks && i < 4; i++) {
        for (uint8_t j = 0; j < phoneChunkLengths[i]; j++) {
          char c = (char)phoneChunkData[i][j];
          if (c != 0) {
            completeMessage += c;
          }
        }
      }
      
      Serial.println("\n[BT] ✓✓✓ COMPLETE BINARY MESSAGE RECEIVED FROM PHONE! ✓✓✓");
      Serial.println("[BT] Total length: " + String(completeMessage.length()) + " bytes");
      
      if (completeMessage.length() > 0) {
        processBluetoothMessage(completeMessage);
      }
      
      // Reset
      isReceivingPhoneChunks = false;
      phoneReceivedChunks = 0;
      memset(phoneChunkData, 0, sizeof(phoneChunkData));
      memset(phoneChunkLengths, 0, sizeof(phoneChunkLengths));
    }
  } else {
    Serial.println("[BT] ⚠ Invalid chunk index or length!");
  }
}

void processBluetoothMessage(String msg) {
  Serial.println("\n==========================================");
  Serial.println("[BT RX] ✓✓✓ MESSAGE FROM PHONE RECEIVED ✓✓✓");
  Serial.println("==========================================");
  Serial.println("[BT RX] Raw message: " + msg);
  Serial.println("[BT RX] Message length: " + String(msg.length()) + " bytes");
  Serial.println("[BT RX] Timestamp: " + String(millis()) + " ms");
  
  // Check if it's a chat message with type and message fields
  if (msg.indexOf("\"type\":") >= 0 && msg.indexOf("\"message\":") >= 0) {
    Serial.println("[BT RX] ✓ Valid JSON message format detected");
    int msgStart = msg.indexOf("\"message\":\"") + 11;
    int msgEnd = msg.indexOf("\"", msgStart);
    
    if (msgStart > 10 && msgEnd > msgStart) {
      String messageText = msg.substring(msgStart, msgEnd);
      Serial.println("[BT->NRF24] Extracted message text: " + messageText);
      
      // Add from_node to message before sending
      String fullMsg = msg;
      if (fullMsg.endsWith("}")) {
        fullMsg.remove(fullMsg.length() - 1);
        fullMsg += ",\"from_node\":\"" + nId + "\"}";
        Serial.println("[BT->NRF24] Full message with node ID: " + fullMsg);
      } else {
        Serial.println("[WARNING] Message doesn't end with '}', appending node ID anyway");
        fullMsg += ",\"from_node\":\"" + nId + "\"}";
      }
      
      Serial.println("[BT->NRF24] ✓ Message validated, preparing to send via NRF24L01...");
      sendViaNRF24(fullMsg);
      Serial.println("[BT->NRF24] ✓ Message sent to NRF24L01 transmission queue");
    } else {
      Serial.println("[ERROR] Could not extract message from JSON");
    }
  } else {
    Serial.println("[WARNING] Message doesn't contain 'type' and 'message' fields, ignoring");
  }
  Serial.println("==========================================\n");
}

void sendViaNRF24(String message) {
  Serial.println("[NRF24 TX] Preparing to send message...");
  
  // Convert message to bytes
  uint8_t msgBytes[256];
  int msgLen = message.length();
  if (msgLen >= sizeof(msgBytes)) {
    Serial.println("[ERROR] Message too long!");
    return;
  }
  message.getBytes(msgBytes, sizeof(msgBytes));
  
  // Calculate number of chunks needed
  uint8_t totalChunks = (msgLen + NRF24_DATA_SIZE - 1) / NRF24_DATA_SIZE;
  
  // Generate unique message ID
  uint32_t msgId = ++messageCounter;
  
  Serial.println("[NRF24 TX] Message ID: " + String(msgId) + ", Length: " + String(msgLen) + " bytes, Chunks: " + String(totalChunks));
  
  // Stop listening to transmit
  radio.stopListening();
  radio.openWritingPipe(address[otherNode]);
  
  // Send each chunk
  bool allSent = true;
  for (uint8_t i = 0; i < totalChunks; i++) {
    uint8_t chunk[NRF24_PAYLOAD_SIZE] = {0};
    ChunkHeader* header = (ChunkHeader*)chunk;
    
    // Fill header
    header->msgId = msgId;
    header->chunkIndex = i;
    header->totalChunks = totalChunks;
    
    // Calculate data start and length for this chunk
    int start = i * NRF24_DATA_SIZE;
    int len = min(NRF24_DATA_SIZE, msgLen - start);
    header->dataLen = len;
    
    // Copy data
    memcpy(chunk + sizeof(ChunkHeader), msgBytes + start, len);
    
    // Send chunk
    bool sent = radio.write(&chunk, NRF24_PAYLOAD_SIZE);
    
    if (sent) {
      Serial.println("[OK] Chunk " + String(i + 1) + "/" + String(totalChunks) + " (" + String(len) + " bytes)");
    } else {
      Serial.println("[FAIL] Chunk " + String(i + 1) + "/" + String(totalChunks));
      allSent = false;
    }
    
    delay(15);  // Small delay between chunks for reliability
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
    
    // Read the chunk
    radio.read(&chunk, NRF24_PAYLOAD_SIZE);
    
    // Get payload size
    uint8_t payloadSize = radio.getPayloadSize();
    
    if (payloadSize < sizeof(ChunkHeader)) {
      Serial.println("[ERROR] Chunk too small! Size: " + String(payloadSize));
      return;
    }
    
    ChunkHeader* header = (ChunkHeader*)chunk;
    uint32_t msgId = header->msgId;
    uint8_t idx = header->chunkIndex;
    uint8_t total = header->totalChunks;
    uint8_t len = header->dataLen;
    
    // Validate chunk data
    if (idx >= 32 || total > 32 || total == 0 || len > NRF24_DATA_SIZE || len == 0) {
      Serial.println("[ERROR] Invalid chunk header! idx=" + String(idx) + " total=" + String(total) + " len=" + String(len));
      return;
    }
    
    Serial.print("[NRF24 RX] Chunk " + String(idx + 1) + "/" + String(total) + " (ID: " + String(msgId) + ", Len: " + String(len) + ")");
    
    // Check if new message or continuing
    if (!isReceiving || receivingMsgId != msgId) {
      // New message - initialize
      receivingMsgId = msgId;
      expectedTotalChunks = total;
      receivedChunkCount = 0;
      isReceiving = true;
      memset(receivingChunks, 0, 32);  // Clear all chunk flags
      memset(chunkLengths, 0, 32);     // Clear chunk lengths
      Serial.println(" - New message stream started.");
    } else {
      Serial.println(" - Continuing message.");
    }
    
    // Store chunk data (only if not already received)
    if (idx < 32 && receivingChunks[idx] == 0) {
      uint8_t* data = chunk + sizeof(ChunkHeader);
      
      // Store chunk data by index (for proper reassembly even if out of order)
      if (len > 0 && len <= NRF24_DATA_SIZE) {
        memcpy(chunkData[idx], data, len);
        chunkLengths[idx] = len;
        
        receivingChunks[idx] = 1;  // Mark chunk as received
        receivedChunkCount++;
        
        Serial.println("[NRF24 RX] ✓ Stored chunk " + String(idx + 1) + " (Total received: " + String(receivedChunkCount) + "/" + String(expectedTotalChunks) + ")");
      } else {
        Serial.println("[ERROR] Invalid chunk length: " + String(len));
      }
    } else if (idx < 32 && receivingChunks[idx] == 1) {
      Serial.println("[NRF24 RX] ⚠ Duplicate chunk " + String(idx + 1) + " ignored.");
    }
    
    // Verify ALL chunks are present before reassembly (not just count)
    bool allChunksReceived = true;
    if (isReceiving && receivedChunkCount >= expectedTotalChunks) {
      // Double-check: verify all chunks from 0 to expectedTotalChunks-1 are present
      for (uint8_t i = 0; i < expectedTotalChunks; i++) {
        if (receivingChunks[i] == 0) {
          allChunksReceived = false;
          Serial.println("[NRF24 RX] ⚠ Missing chunk " + String(i + 1) + ", waiting...");
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
      Serial.println("[NRF24 RX] Starting message reassembly...");
      
      // Reassemble message by concatenating chunks in order (0, 1, 2, ...)
      String receivingMessage = "";
      for (uint8_t i = 0; i < expectedTotalChunks; i++) {
        if (receivingChunks[i] == 1 && chunkLengths[i] > 0) {
          Serial.println("[NRF24 RX] Reassembling chunk " + String(i + 1) + " (" + String(chunkLengths[i]) + " bytes)");
          for (int j = 0; j < chunkLengths[i]; j++) {
            char c = (char)chunkData[i][j];
            if (c != 0) {  // Skip null bytes
              receivingMessage += c;
            }
          }
        }
      }
      
      Serial.println("[NRF24 RX] ✓ Reassembly complete!");
      Serial.println("[NRF24 RX] Total message length: " + String(receivingMessage.length()) + " bytes");
      Serial.println("[NRF24 RX] Full message content: " + receivingMessage);
      Serial.println("[NRF24 RX] Preparing to forward to phone via Bluetooth...");
      Serial.println("==========================================");
      
      // Forward to Bluetooth
      if (receivingMessage.length() > 0) {
        forwardMessageToPhone(receivingMessage);
      } else {
        Serial.println("[ERROR] Reassembled message is empty!");
      }
      
      // Reset for next message
      isReceiving = false;
      receivedChunkCount = 0;
      memset(receivingChunks, 0, 32);
      memset(chunkLengths, 0, 32);
    }
  }
}

void forwardMessageToPhone(String message) {
  Serial.println("\n==========================================");
  Serial.println("[BT TX] 📤 FORWARDING MESSAGE TO PHONE 📤");
  Serial.println("==========================================");
  Serial.println("[BT TX] Checking connection status...");
  Serial.println("[BT TX] conn flag: " + String(conn ? "TRUE" : "FALSE"));
  Serial.println("[BT TX] BT.hasClient(): " + String(BT.hasClient() ? "TRUE" : "FALSE"));
  
  if (conn && BT.hasClient()) {
    Serial.println("[BT TX] ✓ Connection verified! Phone is connected.");
    Serial.println("[BT TX] Message to send: " + message.substring(0, min(100, (int)message.length())));
    Serial.println("[BT TX] Full message length: " + String(message.length()) + " bytes");
    Serial.println("[BT TX] Sending to phone now...");
    
    int bytesWritten = BT.println(message);
    
    if (bytesWritten > 0) {
      Serial.println("==========================================");
      Serial.println("[BT TX] ✓✓✓ MESSAGE SENT TO PHONE! ✓✓✓");
      Serial.println("==========================================");
      Serial.println("[BT TX] Bytes written: " + String(bytesWritten));
      Serial.println("[BT TX] Message preview: " + message.substring(0, min(50, (int)message.length())) + "...");
      Serial.println("[BT TX] Phone should receive this message now!");
      Serial.println("==========================================\n");
    } else {
      Serial.println("[BT TX] ⚠⚠⚠ FAILED TO WRITE TO PHONE! ⚠⚠⚠");
      Serial.println("[BT TX] bytesWritten = " + String(bytesWritten));
      Serial.println("==========================================\n");
    }
  } else {
    Serial.println("==========================================");
    Serial.println("[BT TX] ✗✗✗ CANNOT SEND - NO CONNECTION ✗✗✗");
    Serial.println("==========================================");
    Serial.println("[BT TX FAIL] Phone is NOT connected!");
    Serial.println("[BT TX FAIL] conn=" + String(conn ? "TRUE" : "FALSE"));
    Serial.println("[BT TX FAIL] hasClient=" + String(BT.hasClient() ? "TRUE" : "FALSE"));
    Serial.println("[BT TX FAIL] Message was NOT sent to phone!");
    Serial.println("==========================================\n");
  }
}

void sendStatus() {
  String status = "{\"status\":\"connected\",\"node_id\":\"" + nId + "\"}";
  BT.println(status);
  Serial.println("[STATUS] Sent to phone.");
}
