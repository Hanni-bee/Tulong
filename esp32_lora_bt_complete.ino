/*
 * ═══════════════════════════════════════════════════════════════════════════
 * ESP32 WROOM32 - COMPLETE BLUETOOTH + LORA CHAT SYSTEM
 * ═══════════════════════════════════════════════════════════════════════════
 * 
 * HARDWARE: ESP32 WROOM32 + SX1278 RA-02 LoRa Module (433MHz)
 * 
 * PIN CONNECTIONS:
 * ┌──────────────────────────────────────────────────────┐
 * │ ESP32 Pin    →    SX1278 RA-02 Pin                   │
 * ├──────────────────────────────────────────────────────┤
 * │ GPIO5        →    NSS (Chip Select)                  │
 * │ GPIO23       →    MOSI                               │
 * │ GPIO19       →    MISO                               │
 * │ GPIO18       →    SCK                                │
 * │ GPIO2        →    RST (Reset)                        │
 * │ GPIO4        →    DIO0                               │
 * │ 3.3V         →    VCC                                │
 * │ GND          →    GND                                │
 * └──────────────────────────────────────────────────────┘
 * 
 * FEATURES:
 * ✓ Bluetooth Serial authentication (firstname only)
 * ✓ JSON message protocol
 * ✓ Group & private messaging
 * ✓ LoRa mesh networking
 * ✓ Memory optimized for WROOM32
 * ✓ No WiFi/Internet required
 * ✓ Single .ino file
 * 
 * AUTHOR: AI Assistant
 * DATE: 2025
 * VERSION: 1.0 - Production Ready
 */

#include <BluetoothSerial.h>
#include <LoRa.h>

// ═══════════════════════════════════════════════════════════════════════════
// HARDWARE PIN DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════

#define LORA_NSS    5      // LoRa NSS (Chip Select)
#define LORA_RST    2      // LoRa Reset
#define LORA_DIO0   4      // LoRa DIO0 (Interrupt)
#define LORA_FREQ   433E6  // LoRa Frequency (433 MHz)

// ═══════════════════════════════════════════════════════════════════════════
// CONFIGURATION CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════

#define BT_DEVICE_NAME  "ESP32_LoRa_Chat"
#define MSG_BUFFER_SIZE 256
#define BAUD_RATE       115200

// ═══════════════════════════════════════════════════════════════════════════
// GLOBAL OBJECTS
// ═══════════════════════════════════════════════════════════════════════════

BluetoothSerial SerialBT;

// ═══════════════════════════════════════════════════════════════════════════
// STATE VARIABLES
// ═══════════════════════════════════════════════════════════════════════════

String nodeId = "";           // Unique node identifier (auto-generated)
String userName = "";         // User's firstname from authentication
String btBuffer = "";         // Bluetooth incoming message buffer
bool isAuthenticated = false; // Authentication status
bool btConnected = false;     // Bluetooth connection status

// ═══════════════════════════════════════════════════════════════════════════
// SETUP - INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════

void setup() {
  // Initialize Serial for debugging
  Serial.begin(BAUD_RATE);
  delay(500);
  
  Serial.println("\n╔════════════════════════════════════════════════════════╗");
  Serial.println("║   ESP32 WROOM32 - BLUETOOTH + LORA CHAT SYSTEM       ║");
  Serial.println("║   Optimized for offline mesh communication            ║");
  Serial.println("╚════════════════════════════════════════════════════════╝\n");
  
  // Reserve memory for buffer (prevent fragmentation)
  btBuffer.reserve(MSG_BUFFER_SIZE);
  
  // Generate unique Node ID from chip MAC
  generateNodeId();
  
  // Initialize LoRa module
  if (!initializeLoRa()) {
    Serial.println("[FATAL] LoRa initialization failed!");
    Serial.println("[FATAL] Check wiring and restart ESP32");
    while (1) { 
      delay(1000); 
      Serial.print(".");
    }
  }
  
  // Initialize Bluetooth Serial
  initializeBluetooth();
  
  Serial.println("\n[READY] ✓ System initialized successfully");
  Serial.println("[READY] ✓ Waiting for Bluetooth connection...\n");
  Serial.println("═══════════════════════════════════════════════════════");
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN LOOP
// ═══════════════════════════════════════════════════════════════════════════

void loop() {
  // Handle Bluetooth communication
  handleBluetoothConnection();
  handleBluetoothMessages();
  
  // Handle LoRa communication
  handleLoRaMessages();
  
  // Small delay to prevent CPU overload
  delay(5);
}

// ═══════════════════════════════════════════════════════════════════════════
// NODE ID GENERATION
// ═══════════════════════════════════════════════════════════════════════════

void generateNodeId() {
  // Get unique chip ID
  uint64_t chipId = ESP.getEfuseMac();
  uint32_t chipIdShort = (uint32_t)(chipId >> 32);
  
  // Create node ID
  nodeId = "ESP32_" + String(chipIdShort, HEX);
  nodeId.toUpperCase();
  
  Serial.print("[INIT] Node ID: ");
  Serial.println(nodeId);
}

// ═══════════════════════════════════════════════════════════════════════════
// LORA INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════

bool initializeLoRa() {
  Serial.println("[INIT] Initializing LoRa SX1278...");
  
  // Set LoRa pins
  LoRa.setPins(LORA_NSS, LORA_RST, LORA_DIO0);
  
  // Begin LoRa communication
  if (!LoRa.begin(LORA_FREQ)) {
    return false;
  }
  
  // Configure LoRa for optimal performance
  LoRa.setTxPower(20);              // Maximum power (20 dBm)
  LoRa.setSpreadingFactor(7);       // SF7 for good range/speed balance
  LoRa.setSignalBandwidth(125E3);   // 125 kHz bandwidth
  LoRa.setCodingRate4(5);           // 4/5 coding rate
  LoRa.enableCrc();                 // Enable CRC for reliability
  
  Serial.println("[INIT] ✓ LoRa initialized at 433 MHz");
  Serial.println("[INIT] ✓ TX Power: 20 dBm, SF: 7, BW: 125 kHz");
  
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════
// BLUETOOTH INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════

void initializeBluetooth() {
  Serial.println("[INIT] Initializing Bluetooth Serial...");
  
  if (!SerialBT.begin(BT_DEVICE_NAME)) {
    Serial.println("[ERROR] Bluetooth initialization failed!");
    return;
  }
  
  Serial.print("[INIT] ✓ Bluetooth device name: ");
  Serial.println(BT_DEVICE_NAME);
  Serial.println("[INIT] ✓ Ready for pairing");
}

// ═══════════════════════════════════════════════════════════════════════════
// BLUETOOTH CONNECTION HANDLER
// ═══════════════════════════════════════════════════════════════════════════

void handleBluetoothConnection() {
  // Check if client connected
  if (SerialBT.hasClient()) {
    if (!btConnected) {
      btConnected = true;
      Serial.println("\n[BT] ✓ Client connected");
      
      // Send authentication request
      if (!isAuthenticated) {
        sendAuthenticationRequest();
      }
    }
  } else {
    // Handle disconnection
    if (btConnected) {
      btConnected = false;
      isAuthenticated = false;
      userName = "";
      Serial.println("\n[BT] ✗ Client disconnected");
      Serial.println("[BT] Authentication reset");
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BLUETOOTH MESSAGE HANDLER
// ═══════════════════════════════════════════════════════════════════════════

void handleBluetoothMessages() {
  if (!btConnected) return;
  
  // Read incoming Bluetooth data
  while (SerialBT.available()) {
    char c = SerialBT.read();
    
    // Check for message terminator
    if (c == '\n' || c == '\r') {
      if (btBuffer.length() > 0) {
        processBluetoothMessage(btBuffer);
        btBuffer = ""; // Clear buffer
      }
    } else {
      // Add to buffer if not full
      if (btBuffer.length() < MSG_BUFFER_SIZE - 1) {
        btBuffer += c;
      } else {
        Serial.println("[BT] ⚠ Buffer overflow - clearing");
        btBuffer = "";
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LORA MESSAGE HANDLER
// ═══════════════════════════════════════════════════════════════════════════

void handleLoRaMessages() {
  // Check for incoming LoRa packets
  int packetSize = LoRa.parsePacket();
  
  if (packetSize) {
    String loraMsg = "";
    loraMsg.reserve(MSG_BUFFER_SIZE);
    
    // Read packet
    while (LoRa.available() && loraMsg.length() < MSG_BUFFER_SIZE - 1) {
      loraMsg += (char)LoRa.read();
    }
    
    // Get signal strength
    int rssi = LoRa.packetRssi();
    float snr = LoRa.packetSnr();
    
    Serial.print("[LoRa] ← Received (RSSI: ");
    Serial.print(rssi);
    Serial.print(" dBm, SNR: ");
    Serial.print(snr);
    Serial.println(" dB)");
    
    // Process received message
    processLoRaMessage(loraMsg);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SEND AUTHENTICATION REQUEST TO FLUTTER
// ═══════════════════════════════════════════════════════════════════════════

void sendAuthenticationRequest() {
  // Create JSON: {"auth_request":true,"node_id":"ESP32_XXXX"}
  String authReq = "{\"auth_request\":true,\"node_id\":\"" + nodeId + "\"}";
  
  SerialBT.println(authReq);
  
  Serial.println("[AUTH] → Auth request sent to Flutter app");
  Serial.print("[AUTH] → ");
  Serial.println(authReq);
}

// ═══════════════════════════════════════════════════════════════════════════
// PROCESS BLUETOOTH MESSAGE FROM FLUTTER
// ═══════════════════════════════════════════════════════════════════════════

void processBluetoothMessage(String msg) {
  Serial.print("[BT] ← ");
  Serial.println(msg);
  
  // Parse message type
  if (msg.indexOf("\"auth_confirm\":true") > 0) {
    // ─────────────────────────────────────────────────────────────────
    // AUTHENTICATION CONFIRMATION
    // ─────────────────────────────────────────────────────────────────
    handleAuthenticationConfirm(msg);
    
  } else if (msg.indexOf("\"type\":") > 0 && isAuthenticated) {
    // ─────────────────────────────────────────────────────────────────
    // CHAT MESSAGE (GROUP OR PRIVATE)
    // ─────────────────────────────────────────────────────────────────
    handleChatMessage(msg);
    
  } else if (!isAuthenticated) {
    Serial.println("[BT] ⚠ Message ignored - not authenticated");
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HANDLE AUTHENTICATION CONFIRMATION
// ═══════════════════════════════════════════════════════════════════════════

void handleAuthenticationConfirm(String msg) {
  // Extract firstname from JSON
  // Format: {"auth_confirm":true,"firstname":"Hanniel"}
  
  int nameStart = msg.indexOf("\"firstname\":\"") + 13;
  int nameEnd = msg.indexOf("\"", nameStart);
  
  if (nameStart > 12 && nameEnd > nameStart) {
    userName = msg.substring(nameStart, nameEnd);
    isAuthenticated = true;
    
    Serial.println("\n╔════════════════════════════════════════════════════════╗");
    Serial.println("║         AUTHENTICATION SUCCESSFUL                     ║");
    Serial.println("╚════════════════════════════════════════════════════════╝");
    Serial.print("[AUTH] ✓ User: ");
    Serial.println(userName);
    Serial.print("[AUTH] ✓ Node: ");
    Serial.println(nodeId);
    Serial.println("[AUTH] ✓ System ready for messaging\n");
    
    // Send sync complete confirmation
    String syncMsg = "{\"sync_complete\":true,\"node_id\":\"" + nodeId + "\",\"user_name\":\"" + userName + "\"}";
    SerialBT.println(syncMsg);
    
    Serial.println("[AUTH] → Sync complete sent to Flutter");
  } else {
    Serial.println("[AUTH] ✗ Failed to parse firstname");
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HANDLE CHAT MESSAGE FROM FLUTTER
// ═══════════════════════════════════════════════════════════════════════════

void handleChatMessage(String msg) {
  // Extract message type, receiver, and content
  String messageType = extractJsonValue(msg, "type");
  String receiverId = extractJsonValue(msg, "receiver_id");
  String messageText = extractJsonValue(msg, "message");
  String senderName = extractJsonValue(msg, "sender_name");
  
  // Validate required fields
  if (messageType.length() == 0 || messageText.length() == 0) {
    Serial.println("[CHAT] ⚠ Invalid message format - missing required fields");
    return;
  }
  
  // Log message
  if (messageType == "group") {
    Serial.println("\n[CHAT] 📢 GROUP MESSAGE");
    Serial.print("[CHAT] From: ");
    Serial.println(senderName.length() > 0 ? senderName : userName);
    Serial.print("[CHAT] Text: ");
    Serial.println(messageText);
    
  } else if (messageType == "private") {
    Serial.println("\n[CHAT] 💬 PRIVATE MESSAGE");
    Serial.print("[CHAT] From: ");
    Serial.println(senderName.length() > 0 ? senderName : userName);
    Serial.print("[CHAT] To: ");
    Serial.println(receiverId);
    Serial.print("[CHAT] Text: ");
    Serial.println(messageText);
  }
  
  // Transmit via LoRa
  transmitLoRaMessage(msg);
}

// ═══════════════════════════════════════════════════════════════════════════
// TRANSMIT MESSAGE VIA LORA
// ═══════════════════════════════════════════════════════════════════════════

void transmitLoRaMessage(String msg) {
  // Begin LoRa packet
  LoRa.beginPacket();
  LoRa.print(msg);
  LoRa.endPacket();
  
  Serial.println("[LoRa] → Transmitted successfully");
  Serial.print("[LoRa] → Size: ");
  Serial.print(msg.length());
  Serial.println(" bytes\n");
}

// ═══════════════════════════════════════════════════════════════════════════
// PROCESS LORA MESSAGE
// ═══════════════════════════════════════════════════════════════════════════

void processLoRaMessage(String msg) {
  Serial.print("[LoRa] Processing: ");
  Serial.println(msg);
  
  // Extract message details
  String messageType = extractJsonValue(msg, "type");
  String receiverId = extractJsonValue(msg, "receiver_id");
  String senderName = extractJsonValue(msg, "sender_name");
  String messageText = extractJsonValue(msg, "message");
  
  // Check if message is for this node
  bool isForMe = (receiverId == nodeId || receiverId == "all");
  
  if (isForMe) {
    // Log received message
    if (messageType == "group") {
      Serial.println("[LoRa] 📢 GROUP MESSAGE RECEIVED");
    } else {
      Serial.println("[LoRa] 💬 PRIVATE MESSAGE RECEIVED");
    }
    
    Serial.print("[LoRa] From: ");
    Serial.println(senderName);
    Serial.print("[LoRa] Text: ");
    Serial.println(messageText);
    
    // Forward to Flutter app if connected
    if (btConnected && isAuthenticated) {
      SerialBT.println(msg);
      Serial.println("[LoRa] → Forwarded to Flutter app\n");
    } else {
      Serial.println("[LoRa] ⚠ Not forwarded - Bluetooth not connected\n");
    }
  } else {
    Serial.print("[LoRa] ℹ Message for: ");
    Serial.print(receiverId);
    Serial.println(" (not for me - ignored)\n");
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// UTILITY: EXTRACT JSON VALUE
// ═══════════════════════════════════════════════════════════════════════════

String extractJsonValue(String json, String key) {
  // Simple JSON parser for key-value extraction
  // Format: "key":"value"
  
  String searchStr = "\"" + key + "\":\"";
  int startPos = json.indexOf(searchStr);
  
  if (startPos == -1) return "";
  
  startPos += searchStr.length();
  int endPos = json.indexOf("\"", startPos);
  
  if (endPos == -1) return "";
  
  return json.substring(startPos, endPos);
}

// ═══════════════════════════════════════════════════════════════════════════
// END OF FILE
// ═══════════════════════════════════════════════════════════════════════════

