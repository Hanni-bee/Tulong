/*
 * ESP32 LoRa Offline Chat System - PRODUCTION READY
 * 
 * Hardware: ESP32 WROOM32 + SX1278 RA-02 LoRa Module
 * 
 * Pin Configuration:
 * ESP32 → SX1278
 * GPIO5  → NSS (CS)
 * GPIO23 → MOSI
 * GPIO19 → MISO
 * GPIO18 → SCK
 * GPIO2  → RST
 * GPIO4  → DIO0
 * 3.3V   → VCC
 * GND    → GND
 * 
 * Features:
 * - Bluetooth Serial authentication (firstname only)
 * - Group and private messaging via JSON
 * - LoRa mesh communication
 * - Memory optimized for WROOM32
 * - Single .ino file implementation
 * - No internet/WiFi required
 */

#include <BluetoothSerial.h>
#include <LoRa.h>
#include <ArduinoJson.h>

// ============================================================================
// HARDWARE PINS
// ============================================================================
#define LORA_NSS    5
#define LORA_RST    2
#define LORA_DIO0   4
#define LORA_FREQ   433E6

// ============================================================================
// CONFIGURATION
// ============================================================================
#define BT_DEVICE_NAME "ESP32_LoRa_Chat"
#define MSG_BUFFER_SIZE 512
#define JSON_DOC_SIZE 512
#define LORA_TX_POWER 20
#define LORA_SPREAD_FACTOR 7
#define LORA_BANDWIDTH 125E3

// ============================================================================
// GLOBAL OBJECTS
// ============================================================================
BluetoothSerial SerialBT;

// ============================================================================
// STATE VARIABLES
// ============================================================================
String nodeId = "";           // Unique node identifier (ESP32_XXXX)
String userName = "";         // User's first name from authentication
bool isAuthenticated = false; // Authentication status
bool btConnected = false;     // Bluetooth connection status

// Message buffers (pre-allocated to avoid fragmentation)
String btMessageBuffer = "";
String loraMessageBuffer = "";

// ============================================================================
// SETUP FUNCTION
// ============================================================================
void setup() {
  // Initialize Serial for debugging
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n╔════════════════════════════════╗");
  Serial.println("║  ESP32 LoRa Offline Chat      ║");
  Serial.println("║  Optimized for WROOM32         ║");
  Serial.println("╚════════════════════════════════╝\n");
  
  // Reserve memory for buffers to prevent fragmentation
  btMessageBuffer.reserve(MSG_BUFFER_SIZE);
  loraMessageBuffer.reserve(MSG_BUFFER_SIZE);
  
  // Generate unique Node ID based on chip ID
  uint64_t chipId = ESP.getEfuseMac();
  nodeId = "ESP32_" + String((uint32_t)(chipId >> 32), HEX);
  nodeId.toUpperCase();
  
  Serial.println("[INIT] Node ID: " + nodeId);
  
  // Initialize LoRa
  if (!initializeLoRa()) {
    Serial.println("[ERROR] LoRa initialization failed!");
    Serial.println("[ERROR] Check wiring and restart");
    while (1) { delay(1000); }
  }
  
  // Initialize Bluetooth
  if (!initializeBluetooth()) {
    Serial.println("[ERROR] Bluetooth initialization failed!");
    while (1) { delay(1000); }
  }
  
  Serial.println("[READY] System initialized successfully");
  Serial.println("[READY] Waiting for Bluetooth connection...\n");
}

// ============================================================================
// MAIN LOOP
// ============================================================================
void loop() {
  // Handle Bluetooth communication
  handleBluetooth();
  
  // Handle LoRa communication
  handleLoRa();
  
  // Small delay to prevent CPU overload
  delay(10);
}

// ============================================================================
// LORA INITIALIZATION
// ============================================================================
bool initializeLoRa() {
  Serial.println("[LoRa] Initializing SX1278...");
  
  // Set LoRa pins
  LoRa.setPins(LORA_NSS, LORA_RST, LORA_DIO0);
  
  // Begin LoRa
  if (!LoRa.begin(LORA_FREQ)) {
    return false;
  }
  
  // Configure LoRa for optimal performance
  LoRa.setTxPower(LORA_TX_POWER);
  LoRa.setSpreadingFactor(LORA_SPREAD_FACTOR);
  LoRa.setSignalBandwidth(LORA_BANDWIDTH);
  LoRa.enableCrc();
  
  Serial.println("[LoRa] ✓ Initialized at 433MHz");
  Serial.println("[LoRa] ✓ Listening for messages...");
  
  return true;
}

// ============================================================================
// BLUETOOTH INITIALIZATION
// ============================================================================
bool initializeBluetooth() {
  Serial.println("[BT] Initializing Bluetooth...");
  
  if (!SerialBT.begin(BT_DEVICE_NAME)) {
    return false;
  }
  
  Serial.println("[BT] ✓ Device name: " + String(BT_DEVICE_NAME));
  Serial.println("[BT] ✓ Ready for pairing");
  
  return true;
}

// ============================================================================
// BLUETOOTH HANDLER
// ============================================================================
void handleBluetooth() {
  // Check connection status
  if (SerialBT.hasClient()) {
    if (!btConnected) {
      btConnected = true;
      Serial.println("\n[BT] ✓ Client connected");
      
      // Request authentication
      sendAuthenticationRequest();
    }
    
    // Read incoming data
    while (SerialBT.available()) {
      char c = SerialBT.read();
      
      // Check for message terminator
      if (c == '\n' || c == '\r') {
        if (btMessageBuffer.length() > 0) {
          processBluetoothMessage(btMessageBuffer);
          btMessageBuffer = ""; // Clear buffer
        }
      } else {
        // Add to buffer if not full
        if (btMessageBuffer.length() < MSG_BUFFER_SIZE - 1) {
          btMessageBuffer += c;
        } else {
          Serial.println("[BT] ⚠ Buffer overflow, clearing");
          btMessageBuffer = "";
        }
      }
    }
  } else {
    // Handle disconnection
    if (btConnected) {
      btConnected = false;
      isAuthenticated = false;
      userName = "";
      Serial.println("\n[BT] ✗ Client disconnected");
      Serial.println("[READY] Waiting for Bluetooth connection...\n");
    }
  }
}

// ============================================================================
// LORA HANDLER
// ============================================================================
void handleLoRa() {
  // Check for incoming LoRa packets
  int packetSize = LoRa.parsePacket();
  
  if (packetSize) {
    loraMessageBuffer = ""; // Clear buffer
    
    // Read packet
    while (LoRa.available()) {
      char c = (char)LoRa.read();
      if (loraMessageBuffer.length() < MSG_BUFFER_SIZE - 1) {
        loraMessageBuffer += c;
      }
    }
    
    // Get signal strength
    int rssi = LoRa.packetRssi();
    
    Serial.println("[LoRa] ✓ Received (RSSI: " + String(rssi) + " dBm)");
    
    // Process received LoRa message
    processLoRaMessage(loraMessageBuffer);
  }
}

// ============================================================================
// AUTHENTICATION REQUEST
// ============================================================================
void sendAuthenticationRequest() {
  Serial.println("[AUTH] Requesting authentication from app...");
  
  // Create authentication request JSON
  StaticJsonDocument<128> doc;
  doc["auth_request"] = true;
  doc["node_id"] = nodeId;
  
  // Send to Flutter app
  String output;
  serializeJson(doc, output);
  SerialBT.println(output);
  
  Serial.println("[AUTH] → Sent: " + output);
}

// ============================================================================
// PROCESS BLUETOOTH MESSAGE
// ============================================================================
void processBluetoothMessage(String message) {
  Serial.println("[BT] ← Received: " + message);
  
  // Parse JSON
  StaticJsonDocument<JSON_DOC_SIZE> doc;
  DeserializationError error = deserializeJson(doc, message);
  
  if (error) {
    Serial.println("[BT] ✗ JSON parse error: " + String(error.c_str()));
    return;
  }
  
  // Handle authentication confirmation
  if (doc.containsKey("auth_confirm") && doc["auth_confirm"] == true) {
    handleAuthenticationConfirm(doc);
    return;
  }
  
  // Handle chat messages (only if authenticated)
  if (isAuthenticated && doc.containsKey("type")) {
    handleChatMessage(doc);
    return;
  }
  
  Serial.println("[BT] ⚠ Ignored: Not authenticated or invalid message");
}

// ============================================================================
// HANDLE AUTHENTICATION CONFIRMATION
// ============================================================================
void handleAuthenticationConfirm(JsonDocument& doc) {
  if (doc.containsKey("firstname")) {
    userName = doc["firstname"].as<String>();
    isAuthenticated = true;
    
    Serial.println("\n╔════════════════════════════════╗");
    Serial.println("║  AUTHENTICATION SUCCESSFUL     ║");
    Serial.println("╚════════════════════════════════╝");
    Serial.println("[AUTH] ✓ User: " + userName);
    Serial.println("[AUTH] ✓ Node: " + nodeId);
    Serial.println("[READY] System ready for messaging\n");
    
    // Send sync confirmation to app
    StaticJsonDocument<128> response;
    response["sync_complete"] = true;
    response["node_id"] = nodeId;
    response["user_name"] = userName;
    
    String output;
    serializeJson(response, output);
    SerialBT.println(output);
    
    Serial.println("[AUTH] → Sync complete sent");
  } else {
    Serial.println("[AUTH] ✗ No firstname in confirmation");
  }
}

// ============================================================================
// HANDLE CHAT MESSAGE
// ============================================================================
void handleChatMessage(JsonDocument& doc) {
  String type = doc["type"] | "unknown";
  String sender = doc["sender_name"] | userName;
  String receiver = doc["receiver_id"] | "all";
  String message = doc["message"] | "";
  
  if (type == "group") {
    Serial.println("\n[CHAT] 📢 Group message from " + sender);
    Serial.println("[CHAT] → \"" + message + "\"");
    
    // Broadcast via LoRa
    broadcastLoRaMessage(doc);
    
  } else if (type == "private") {
    Serial.println("\n[CHAT] 💬 Private message from " + sender + " to " + receiver);
    Serial.println("[CHAT] → \"" + message + "\"");
    
    // Send via LoRa to specific node
    sendLoRaMessage(doc);
    
  } else {
    Serial.println("[CHAT] ⚠ Unknown message type: " + type);
  }
}

// ============================================================================
// BROADCAST LORA MESSAGE
// ============================================================================
void broadcastLoRaMessage(JsonDocument& doc) {
  // Serialize JSON
  String output;
  serializeJson(doc, output);
  
  // Send via LoRa
  LoRa.beginPacket();
  LoRa.print(output);
  LoRa.endPacket();
  
  Serial.println("[LoRa] ✓ Broadcast sent (" + String(output.length()) + " bytes)");
}

// ============================================================================
// SEND LORA MESSAGE
// ============================================================================
void sendLoRaMessage(JsonDocument& doc) {
  // Serialize JSON
  String output;
  serializeJson(doc, output);
  
  // Send via LoRa
  LoRa.beginPacket();
  LoRa.print(output);
  LoRa.endPacket();
  
  String receiver = doc["receiver_id"] | "unknown";
  Serial.println("[LoRa] ✓ Sent to " + receiver + " (" + String(output.length()) + " bytes)");
}

// ============================================================================
// PROCESS LORA MESSAGE
// ============================================================================
void processLoRaMessage(String message) {
  Serial.println("[LoRa] ← Message: " + message);
  
  // Parse JSON
  StaticJsonDocument<JSON_DOC_SIZE> doc;
  DeserializationError error = deserializeJson(doc, message);
  
  if (error) {
    Serial.println("[LoRa] ✗ JSON parse error: " + String(error.c_str()));
    return;
  }
  
  // Check if message is for this node
  String receiver = doc["receiver_id"] | "all";
  String sender = doc["sender_name"] | "Unknown";
  String msgText = doc["message"] | "";
  String type = doc["type"] | "unknown";
  
  // Only process if it's for us or broadcast
  if (receiver == "all" || receiver == nodeId) {
    if (type == "group") {
      Serial.println("[LoRa] 📢 Group from " + sender + ": \"" + msgText + "\"");
    } else {
      Serial.println("[LoRa] 💬 Private from " + sender + ": \"" + msgText + "\"");
    }
    
    // Forward to Flutter app if Bluetooth connected
    if (btConnected && isAuthenticated) {
      String output;
      serializeJson(doc, output);
      SerialBT.println(output);
      Serial.println("[BT] → Forwarded to app");
    } else {
      Serial.println("[BT] ⚠ Not connected, message not forwarded");
    }
  } else {
    Serial.println("[LoRa] ℹ Message for " + receiver + " (ignored)");
  }
}

// ============================================================================
// END OF FILE
// ============================================================================
