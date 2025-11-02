/*
 * ESP32 NODE B - 4MB FLASH OPTIMIZED
 * Device: ESP32 WROOM32 (4MB Flash)
 * Device Name: ESP32_Node_B
 * 
 * OPTIMIZED FOR 4MB FLASH:
 * - Minimal memory usage
 * - No external libraries beyond essentials
 * - Compact JSON handling
 * - Efficient NRF24L01 communication
 * 
 * Wiring: 
 * NRF24L01 → ESP32
 * CE  → GPIO26
 * CSN → GPIO27
 * MOSI → GPIO23
 * MISO → GPIO19
 * SCK → GPIO18
 * VCC → 3.3V
 * GND → GND
 */

#include <BluetoothSerial.h>
#include <SPI.h>
#include <nRF24L01.h>
#include <RF24.h>

// NRF24L01 pins
#define CE_PIN 26
#define CSN_PIN 27

// Device name
#define BT_DEVICE_NAME "ESP32_Node_B"

BluetoothSerial BT;
RF24 radio(CE_PIN, CSN_PIN); // CE, CSN

// NRF24L01 pipe addresses (different for each node)
const byte address[][6] = {"1Node", "2Node"}; // Node B listens on pipe 0, sends on pipe 1
const byte thisNode = 0; // This node listens on address[0]

String nId = "";
String buf = "";
bool conn = false;
unsigned long lastCheck = 0;
unsigned long lastPresence = 0;

// Binary chunking for large messages
#define MAX_CHUNK_SIZE 512
#define MAX_CHUNKS 10
struct MessageChunk {
  uint32_t msgId;
  uint16_t chunkIndex;
  uint16_t totalChunks;
  uint16_t dataLength;
  uint8_t data[MAX_CHUNK_SIZE];
  bool received;
};

MessageChunk chunks[MAX_CHUNKS];
uint32_t currentMsgId = 0;
uint8_t chunkBuffer[MAX_CHUNK_SIZE * MAX_CHUNKS];
uint16_t chunkBufferPos = 0;
bool receivingChunks = false;
uint16_t expectedChunks = 0;
uint16_t receivedChunkCount = 0;

// User discovery (minimal)
struct User {
  String nodeId;
  int signal;
  unsigned long lastSeen;
  bool online;
};

User users[5]; // Max 5 users to save memory
int userCount = 0;

void setup() {
  Serial.begin(115200);
  delay(500);
  
  // Generate Node ID
  uint64_t c = ESP.getEfuseMac();
  nId = "NodeB_" + String((uint32_t)(c >> 32), HEX);
  nId.toUpperCase();
  
  Serial.println("\n=== ESP32 NODE B (4MB) ===");
  Serial.println("Device: " + String(BT_DEVICE_NAME));
  Serial.println("Node ID: " + nId);
  Serial.println("Radio: NRF24L01");
  
  // Init SPI for NRF24L01
  SPI.begin(18, 19, 23, -1); // SCK, MISO, MOSI, SS (SS not used with CSN)
  
  // Init NRF24L01
  if (!radio.begin()) {
    Serial.println("[ERROR] NRF24L01 failed!");
    while(1) delay(1000);
  }
  
  // Configure NRF24L01
  radio.setPALevel(RF24_PA_MAX);        // Power level (MAX = highest power)
  radio.setDataRate(RF24_250KBPS);      // Data rate (250KBPS for longer range)
  radio.setChannel(76);                 // Channel (0-125, 76 = 2.476 GHz)
  radio.setAutoAck(true);               // Enable auto-acknowledgment
  radio.setRetries(15, 15);             // Retry 15 times with 2500us delay
  radio.setCRCLength(RF24_CRC_16);      // 16-bit CRC
  radio.openReadingPipe(thisNode, address[thisNode]); // Listen on this node's address
  radio.startListening();                // Start listening
  
  Serial.println("[OK] NRF24L01 ready");
  Serial.println("[INFO] Channel: 76, Power: MAX, DataRate: 250KBPS");
  
  // Init BT
  BT.begin(BT_DEVICE_NAME);
  Serial.println("[OK] BT ready");
  Serial.println("[READY] Waiting...\n");
}

void loop() {
  // Health check
  if (millis() - lastCheck > 5000) {
    lastCheck = millis();
    if (conn && !BT.hasClient()) {
      conn = false;
      Serial.println("[WARN] Client disconnected");
    }
  }
  
  // Broadcast presence every 30s
  if (millis() - lastPresence > 30000) {
    broadcastPresence();
    lastPresence = millis();
  }
  
  // Update users (mark offline after 60s)
  updateUsers();
  
  // Handle BT
  if (BT.hasClient()) {
    if (!conn) {
      conn = true;
      Serial.println("\n[BT] Client connected");
      sendStatus();
    }
    
    // Handle incoming data
    while (BT.available()) {
      // Check if we're receiving chunks
      if (receivingChunks) {
        // Continue receiving chunks - chunk type already detected
        handleBinaryChunk();
      } else {
        // Peek at first byte to determine message type
        // Since peek() may not be available, read and check
        if (BT.available() > 0) {
          int firstByte = BT.read();
          
          if (firstByte == 0x01 || firstByte == 0x02 || firstByte == 0x03) {
            // Binary chunk detected - process it
            receivingChunks = true;
            processChunkFromFirstByte((uint8_t)firstByte);
          } else if (firstByte == '{' || firstByte >= 32) {
            // JSON text message - read line normally
            buf = "";
            buf += (char)firstByte;
            
            while (BT.available()) {
              char c = BT.read();
              if (c == '\n' || c == '\r') {
                if (buf.length() > 0) {
                  handleBT(buf);
                  buf = "";
                }
                break;
              } else if (buf.length() < 512) {
                buf += c;
              } else {
                buf = ""; // Clear on overflow
                break;
              }
            }
          } else {
            // Unknown byte - store in buffer (might be part of text)
            buf += (char)firstByte;
          }
        }
      }
    }
  } else {
    if (conn) {
      conn = false;
      Serial.println("[BT] Client disconnected");
    }
  }
  
  // Handle NRF24L01
  if (radio.available()) {
    char text[256] = {0};
    uint8_t bytesRead = radio.read(&text, sizeof(text) - 1);
    
    if (bytesRead > 0) {
      text[bytesRead] = '\0'; // Null terminate
      String msg = String(text);
      
      Serial.println("[NRF24] RX (" + String(bytesRead) + " bytes): " + msg);
      
      // Parse and handle message (use 0 as RSSI placeholder - NRF24L01 doesn't provide direct RSSI)
      handleNRF24(msg, 0);
    }
  }
  
  delay(10);
}

void handleBT(String m) {
  Serial.println("[BT] RX: " + m);
  
  // Send ack
  if (conn) BT.println("{\"ack\":\"ok\"}");
  
  // Check message type
  if (m.indexOf("\"discover_users\"") >= 0) {
    sendUsers();
  } else if (m.indexOf("\"change_frequency\"") >= 0) {
    // Extract frequency (simplified)
    int freqStart = m.indexOf("\"frequency\":") + 12;
    int freqEnd = m.indexOf(",", freqStart);
    if (freqEnd == -1) freqEnd = m.indexOf("}", freqStart);
    
    if (freqStart > 11 && freqEnd > freqStart) {
      String freqStr = m.substring(freqStart, freqEnd);
      long newFreq = freqStr.toInt();
      changeFrequency(newFreq);
    }
  } else if (m.indexOf("\"type\":") >= 0) {
    // Chat message
    handleChat(m);
  }
}

void handleNRF24(String msg, int rssi) {
  // Check if presence broadcast
  if (msg.indexOf("\"presence\":true") >= 0) {
    handlePresence(msg, rssi);
    return;
  }
  
  // Check if for this node
  if (msg.indexOf("\"receiver_id\":\"all\"") >= 0 || 
      msg.indexOf("\"receiver_id\":\"" + nId + "\"") >= 0) {
    
    // Forward to BT
    if (conn && BT.hasClient()) {
      BT.println(msg);
      Serial.println("[NRF24→BT] Forwarded");
    }
  }
}

void handlePresence(String msg, int rssi) {
  // Extract node ID
  int idStart = msg.indexOf("\"node_id\":\"") + 11;
  int idEnd = msg.indexOf("\"", idStart);
  
  if (idStart > 10 && idEnd > idStart) {
    String nodeId = msg.substring(idStart, idEnd);
    
    // Update user list
    updateUser(nodeId, rssi);
    Serial.println("[PRESENCE] User: " + nodeId);
  }
}

void handleChat(String msg) {
  Serial.println("[BT] Chat message received: " + msg);
  
  // Parse JSON to extract message content
  int typeStart = msg.indexOf("\"type\":");
  int messageStart = msg.indexOf("\"message\":");
  
  if (messageStart >= 0) {
    // Extract message text
    int msgValueStart = msg.indexOf("\"", messageStart + 10) + 1;
    int msgValueEnd = msg.indexOf("\"", msgValueStart);
    
    if (msgValueStart > 0 && msgValueEnd > msgValueStart) {
      String messageText = msg.substring(msgValueStart, msgValueEnd);
      Serial.println("[MSG] " + messageText);
      
      // Print to serial monitor
      Serial.println("=========================================");
      Serial.println("MESSAGE FROM PHONE:");
      Serial.println(messageText);
      Serial.println("=========================================");
    }
  }
  
  // Add from_node to message
  String nrfMsg = msg;
  if (nrfMsg.endsWith("}")) {
    nrfMsg = nrfMsg.substring(0, nrfMsg.length() - 1);
    nrfMsg += ",\"from_node\":\"" + nId + "\"}";
  }
  
  // Send via NRF24L01
  radio.stopListening(); // Stop listening to transmit
  
  // Try to send to other nodes (pipe 1 for Node A, or broadcast)
  // For broadcast, we can use address[1] or send to multiple pipes
  radio.openWritingPipe(address[1]); // Send to Node A (or change for other nodes)
  
  char message[256];
  nrfMsg.toCharArray(message, sizeof(message));
  bool sent = radio.write(&message, strlen(message));
  
  radio.startListening(); // Resume listening
  
  if (sent) {
    Serial.println("[NRF24] TX: " + nrfMsg);
  } else {
    Serial.println("[NRF24] TX FAILED: " + nrfMsg);
  }
}

void broadcastPresence() {
  String presence = "{\"presence\":true,\"node_id\":\"" + nId + "\",\"user_name\":\"NodeB_User\",\"frequency\":2476000000}"; // 2.476 GHz = channel 76
  
  // Send via NRF24L01
  radio.stopListening();
  radio.openWritingPipe(address[1]); // Broadcast to other nodes
  
  char message[256];
  presence.toCharArray(message, sizeof(message));
  bool sent = radio.write(&message, strlen(message));
  
  radio.startListening();
  
  if (sent) {
    Serial.println("[PRESENCE] Broadcasted");
  } else {
    Serial.println("[PRESENCE] Broadcast failed");
  }
}

void updateUser(String nodeId, int signal) {
  // Check if user exists
  for (int i = 0; i < userCount; i++) {
    if (users[i].nodeId == nodeId) {
      users[i].signal = signal;
      users[i].lastSeen = millis();
      users[i].online = true;
      return;
    }
  }
  
  // Add new user if space
  if (userCount < 5) {
    users[userCount].nodeId = nodeId;
    users[userCount].signal = signal;
    users[userCount].lastSeen = millis();
    users[userCount].online = true;
    userCount++;
  }
}

void updateUsers() {
  unsigned long now = millis();
  for (int i = 0; i < userCount; i++) {
    if (now - users[i].lastSeen > 60000) {
      users[i].online = false;
    }
  }
}

void sendUsers() {
  String usersJson = "{\"discovered_users\":true,\"users\":[";
  
  for (int i = 0; i < userCount; i++) {
    if (i > 0) usersJson += ",";
    usersJson += "{\"nodeId\":\"" + users[i].nodeId + "\",";
    usersJson += "\"name\":\"User" + String(i + 1) + "\",";
    usersJson += "\"signalStrength\":" + String(users[i].signal) + ",";
    usersJson += "\"isOnline\":" + String(users[i].online ? "true" : "false") + "}";
  }
  
  usersJson += "]}";
  
  if (conn && BT.hasClient()) {
    BT.println(usersJson);
    Serial.println("[DISCOVERY] Sent " + String(userCount) + " users");
  }
}

void changeFrequency(long newFreq) {
  // NRF24L01 uses 2.4 GHz ISM band (channels 0-125)
  // Channel number = (frequency - 2400) / 5 (in MHz)
  // Example: 2400 MHz = channel 0, 2525 MHz = channel 125
  if (newFreq >= 2400000000 && newFreq <= 2525000000) {
    uint8_t channel = (newFreq / 1000000 - 2400) / 5;
    if (channel <= 125) {
      radio.setChannel(channel);
      Serial.println("[FREQ] Channel changed to " + String(channel) + " (" + String(newFreq / 1000000.0) + " MHz)");
      if (conn) BT.println("{\"frequency_changed\":true}");
    } else {
      Serial.println("[FREQ] Invalid channel");
    }
  } else {
    Serial.println("[FREQ] NRF24L01 supports 2400-2525 MHz range");
  }
}

void handleBinaryChunk() {
  if (BT.available() < 10) return; // Need at least rest of header after type byte
  
  uint8_t chunkType = BT.read();
  if (chunkType != 0x01 && chunkType != 0x02 && chunkType != 0x03) {
    Serial.println("[ERROR] Invalid chunk type: 0x" + String(chunkType, HEX));
    receivingChunks = false;
    return;
  }
  
  // Read header
  uint32_t msgId = 0;
  uint16_t chunkIndex = 0;
  uint16_t totalChunks = 0;
  uint16_t dataLength = 0;
  
  // Read message ID (4 bytes, little-endian)
  for (int i = 0; i < 4 && BT.available(); i++) {
    msgId |= ((uint32_t)BT.read()) << (i * 8);
  }
  
  // Read chunk index (2 bytes, little-endian)
  if (BT.available() >= 2) {
    chunkIndex = BT.read();
    chunkIndex |= BT.read() << 8;
  }
  
  // Read total chunks (2 bytes, little-endian)
  if (BT.available() >= 2) {
    totalChunks = BT.read();
    totalChunks |= BT.read() << 8;
  }
  
  // Read data length (2 bytes, little-endian)
  if (BT.available() >= 2) {
    dataLength = BT.read();
    dataLength |= BT.read() << 8;
  }
  
  if (dataLength > MAX_CHUNK_SIZE) {
    Serial.println("[ERROR] Chunk too large: " + String(dataLength));
    receivingChunks = false;
    return;
  }
  
  // Read data
  uint8_t chunkData[MAX_CHUNK_SIZE];
  int bytesRead = 0;
  while (bytesRead < dataLength && BT.available()) {
    chunkData[bytesRead++] = BT.read();
  }
  
  if (bytesRead < dataLength) {
    Serial.println("[WARN] Incomplete chunk data. Expected: " + String(dataLength) + ", Got: " + String(bytesRead));
    return; // Wait for more data
  }
  
  Serial.println("[BT] Chunk " + String(chunkIndex + 1) + "/" + String(totalChunks) + 
                 " (ID: " + String(msgId) + ", Len: " + String(dataLength) + ")");
  
  if (chunkType == 0x01) {
    // First chunk - initialize
    receivingChunks = true;
    currentMsgId = msgId;
    expectedChunks = totalChunks;
    receivedChunkCount = 0;
    chunkBufferPos = 0;
    
    // Clear all chunks for this message
    for (int i = 0; i < MAX_CHUNKS; i++) {
      chunks[i].received = false;
    }
  }
  
  if (receivingChunks && currentMsgId == msgId) {
    // Store chunk
    if (chunkIndex < MAX_CHUNKS) {
      chunks[chunkIndex].msgId = msgId;
      chunks[chunkIndex].chunkIndex = chunkIndex;
      chunks[chunkIndex].totalChunks = totalChunks;
      chunks[chunkIndex].dataLength = dataLength;
      memcpy(chunks[chunkIndex].data, chunkData, dataLength);
      chunks[chunkIndex].received = true;
      receivedChunkCount++;
      
      // Copy to buffer
      memcpy(chunkBuffer + chunkBufferPos, chunkData, dataLength);
      chunkBufferPos += dataLength;
    }
    
    if (chunkType == 0x03 || (receivedChunkCount >= expectedChunks && chunkIndex == totalChunks - 1)) {
      // Last chunk - reassemble and process
      if (chunkBufferPos > 0) {
        chunkBuffer[chunkBufferPos] = 0; // Null terminate
        String fullMessage = String((char*)chunkBuffer);
        
        Serial.println("[BT] Reassembled message (" + String(chunkBufferPos) + " bytes)");
        Serial.println("[BT] Full message: " + fullMessage);
        
        // Process as JSON message
        handleBT(fullMessage);
        
        // Reset
        receivingChunks = false;
        chunkBufferPos = 0;
        receivedChunkCount = 0;
      }
    }
  }
}

void processChunkFromFirstByte(uint8_t chunkType) {
  // Process chunk when we've already read the type byte
  if (BT.available() < 10) {
    // Not enough data yet, wait
    receivingChunks = false;
    return;
  }
  
  // Read rest of header
  uint32_t msgId = 0;
  uint16_t chunkIndex = 0;
  uint16_t totalChunks = 0;
  uint16_t dataLength = 0;
  
  // Read message ID (4 bytes, little-endian)
  for (int i = 0; i < 4 && BT.available(); i++) {
    msgId |= ((uint32_t)BT.read()) << (i * 8);
  }
  
  // Read chunk index (2 bytes, little-endian)
  if (BT.available() >= 2) {
    chunkIndex = BT.read();
    chunkIndex |= BT.read() << 8;
  }
  
  // Read total chunks (2 bytes, little-endian)
  if (BT.available() >= 2) {
    totalChunks = BT.read();
    totalChunks |= BT.read() << 8;
  }
  
  // Read data length (2 bytes, little-endian)
  if (BT.available() >= 2) {
    dataLength = BT.read();
    dataLength |= BT.read() << 8;
  }
  
  if (dataLength > MAX_CHUNK_SIZE) {
    Serial.println("[ERROR] Chunk too large: " + String(dataLength));
    receivingChunks = false;
    return;
  }
  
  // Read data
  uint8_t chunkData[MAX_CHUNK_SIZE];
  int bytesRead = 0;
  while (bytesRead < dataLength && BT.available()) {
    chunkData[bytesRead++] = BT.read();
  }
  
  if (bytesRead < dataLength) {
    Serial.println("[WARN] Incomplete chunk data. Expected: " + String(dataLength) + ", Got: " + String(bytesRead));
    receivingChunks = false;
    return;
  }
  
  Serial.println("[BT] Chunk " + String(chunkIndex + 1) + "/" + String(totalChunks) + 
                 " (ID: " + String(msgId) + ", Len: " + String(dataLength) + ")");
  
  if (chunkType == 0x01) {
    // First chunk - initialize
    receivingChunks = true;
    currentMsgId = msgId;
    expectedChunks = totalChunks;
    receivedChunkCount = 0;
    chunkBufferPos = 0;
    
    for (int i = 0; i < MAX_CHUNKS; i++) {
      chunks[i].received = false;
    }
  }
  
  if (receivingChunks && currentMsgId == msgId) {
    if (chunkIndex < MAX_CHUNKS) {
      chunks[chunkIndex].msgId = msgId;
      chunks[chunkIndex].chunkIndex = chunkIndex;
      chunks[chunkIndex].totalChunks = totalChunks;
      chunks[chunkIndex].dataLength = dataLength;
      memcpy(chunks[chunkIndex].data, chunkData, dataLength);
      chunks[chunkIndex].received = true;
      receivedChunkCount++;
      
      memcpy(chunkBuffer + chunkBufferPos, chunkData, dataLength);
      chunkBufferPos += dataLength;
    }
    
    if (chunkType == 0x03 || (receivedChunkCount >= expectedChunks && chunkIndex == totalChunks - 1)) {
      if (chunkBufferPos > 0) {
        chunkBuffer[chunkBufferPos] = 0;
        String fullMessage = String((char*)chunkBuffer);
        Serial.println("[BT] Reassembled (" + String(chunkBufferPos) + " bytes): " + fullMessage);
        handleBT(fullMessage);
        receivingChunks = false;
        chunkBufferPos = 0;
        receivedChunkCount = 0;
      }
    }
  }
}

void sendStatus() {
  String status = "{\"status\":\"connected\",\"node_id\":\"" + nId + "\",\"frequency\":2476000000}"; // 2.476 GHz = channel 76
  BT.println(status);
  Serial.println("[STATUS] Sent");
}
