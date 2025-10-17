/*
 * ESP32 LoRa Bluetooth Chat System
 * Complete offline messaging with SX1278 LoRa module
 * Single .ino file implementation
 * 
 * Hardware Configuration:
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
 * - Bluetooth Classic Serial communication
 * - LoRa 433MHz messaging
 * - Dynamic user authentication
 * - Group and private messaging
 * - Multi-node scalable setup
 * - Persistent storage with Preferences
 */

#include <BluetoothSerial.h>
#include <SPI.h>
#include <LoRa.h>
#include <WiFi.h>
#include <ArduinoJson.h>
#include <Preferences.h>

// ============================================================================
// HARDWARE CONFIGURATION
// ============================================================================

// LoRa module pins
#define LORA_NSS    5    // NSS (CS) pin
#define LORA_RST    2    // RST pin  
#define LORA_DIO0   4    // DIO0 pin
#define LORA_FREQ   433E6 // 433MHz frequency

// Bluetooth configuration
#define BT_DEVICE_NAME "ESP32_LoRa_Node"

// ============================================================================
// GLOBAL VARIABLES
// ============================================================================

// Bluetooth Serial instance
BluetoothSerial SerialBT;

// Preferences for persistent storage
Preferences preferences;

// Node identification
String nodeId = "";
String nodeMac = "";
String userName = "";
bool isAuthenticated = false;
bool bluetoothConnected = false;

// Message handling
String incomingMessage = "";
unsigned long lastHeartbeat = 0;
const unsigned long HEARTBEAT_INTERVAL = 10000; // 10 seconds

// Connection retry
unsigned long lastConnectionAttempt = 0;
const unsigned long CONNECTION_RETRY_INTERVAL = 5000; // 5 seconds

// ============================================================================
// SETUP FUNCTION
// ============================================================================

void setup() {
  // Initialize Serial for debugging
  Serial.begin(115200);
  Serial.println();
  Serial.println("==========================================");
  Serial.println("ESP32 LoRa Bluetooth Chat System Starting");
  Serial.println("==========================================");
  
  // Initialize WiFi to get MAC address
  WiFi.mode(WIFI_STA);
  nodeMac = WiFi.macAddress();
  
  // Generate unique node ID from MAC (last 6 hex chars)
  String macSuffix = nodeMac.substring(12); // Get last 6 chars (AA:BB:CC:DD:EE:FF -> EE:FF)
  macSuffix.replace(":", ""); // Remove colons
  nodeId = "ESP32_" + macSuffix;
  
  Serial.println("[INFO] Node MAC: " + nodeMac);
  Serial.println("[INFO] Node ID: " + nodeId);
  
  // Initialize Preferences
  preferences.begin("lora_chat", false);
  
  // Load stored user data
  loadStoredUserData();
  
  // Initialize LoRa
  initializeLoRa();
  
  // Initialize Bluetooth
  initializeBluetooth();
  
  Serial.println("[INFO] System initialized successfully!");
  Serial.println("[INFO] Waiting for Bluetooth connection...");
  Serial.println("==========================================");
}

// ============================================================================
// LOOP FUNCTION
// ============================================================================

void loop() {
  // Handle Bluetooth communication
  handleBluetoothCommunication();
  
  // Handle LoRa communication
  handleLoRaCommunication();
  
  // Handle connection retry if disconnected
  handleConnectionRetry();
  
  // Send periodic heartbeat if authenticated
  sendHeartbeat();
  
  // Small delay to prevent overwhelming the system
  delay(10);
}

// ============================================================================
// LORA INITIALIZATION
// ============================================================================

void initializeLoRa() {
  Serial.println("[LORA] Initializing LoRa module...");
  
  // Set up LoRa pins
  LoRa.setPins(LORA_NSS, LORA_RST, LORA_DIO0);
  
  // Initialize LoRa with 433MHz frequency
  if (!LoRa.begin(LORA_FREQ)) {
    Serial.println("[ERROR] LoRa initialization failed!");
    while (1) {
      delay(1000);
      Serial.println("[ERROR] LoRa still not working, retrying...");
    }
  }
  
  // Configure LoRa settings for optimal range
  LoRa.setTxPower(20);        // Max power
  LoRa.setSpreadingFactor(7); // Good balance of range and speed
  LoRa.setSignalBandwidth(125E3); // 125kHz bandwidth
  LoRa.setCodingRate4(5);     // Error correction
  
  // Set up LoRa receive callback
  LoRa.onReceive(onLoRaReceive);
  LoRa.receive(); // Start listening
  
  Serial.println("[LORA] LoRa initialized successfully!");
  Serial.println("[LORA] Frequency: 433MHz");
  Serial.println("[LORA] Listening for messages...");
}

// ============================================================================
// BLUETOOTH INITIALIZATION
// ============================================================================

void initializeBluetooth() {
  Serial.println("[BT] Initializing Bluetooth...");
  
  // Start Bluetooth Serial with device name
  if (!SerialBT.begin(BT_DEVICE_NAME)) {
    Serial.println("[ERROR] Bluetooth initialization failed!");
    return;
  }
  
  Serial.println("[BT] Bluetooth initialized successfully!");
  Serial.println("[BT] Device name: " + String(BT_DEVICE_NAME));
  Serial.println("[BT] MAC address: " + nodeMac);
}

// ============================================================================
// BLUETOOTH COMMUNICATION HANDLER
// ============================================================================

void handleBluetoothCommunication() {
  // Check if Bluetooth is connected
  if (SerialBT.hasClient()) {
    if (!bluetoothConnected) {
      bluetoothConnected = true;
      Serial.println("[BT] Client connected!");
      
      // Send authentication request if not authenticated
      if (!isAuthenticated) {
        sendAuthRequest();
      }
    }
    
    // Read incoming messages
    while (SerialBT.available()) {
      char c = SerialBT.read();
      
      if (c == '\n') {
        // Process complete message
        processBluetoothMessage(incomingMessage);
        incomingMessage = "";
      } else {
        incomingMessage += c;
      }
    }
  } else {
    if (bluetoothConnected) {
      bluetoothConnected = false;
      Serial.println("[BT] Client disconnected!");
    }
  }
}

// ============================================================================
// LORA COMMUNICATION HANDLER
// ============================================================================

void handleLoRaCommunication() {
  // LoRa receive is handled by callback function
  // This function is here for future expansion
}

// ============================================================================
// LORA RECEIVE CALLBACK
// ============================================================================

void onLoRaReceive(int packetSize) {
  if (packetSize == 0) return;
  
  String receivedData = "";
  while (LoRa.available()) {
    receivedData += (char)LoRa.read();
  }
  
  Serial.println("[LORA] Received packet: " + receivedData);
  
  // Process received LoRa message
  processLoRaMessage(receivedData);
}

// ============================================================================
// MESSAGE PROCESSING FUNCTIONS
// ============================================================================

void processBluetoothMessage(String message) {
  Serial.println("[BT] Processing message: " + message);
  
  // Parse JSON message
  DynamicJsonDocument doc(1024);
  DeserializationError error = deserializeJson(doc, message);
  
  if (error) {
    Serial.println("[ERROR] Invalid JSON from Bluetooth: " + message);
    return;
  }
  
  // Handle authentication confirmation
  if (doc.containsKey("auth_confirm") && doc["auth_confirm"] == true) {
    handleAuthConfirmation(doc);
    return;
  }
  
  // Handle chat messages
  if (doc.containsKey("type")) {
    String messageType = doc["type"];
    
    if (messageType == "group") {
      handleGroupMessage(doc);
    } else if (messageType == "private") {
      handlePrivateMessage(doc);
    }
  }
}

void processLoRaMessage(String message) {
  Serial.println("[LORA] Processing LoRa message: " + message);
  
  // Parse JSON message
  DynamicJsonDocument doc(1024);
  DeserializationError error = deserializeJson(doc, message);
  
  if (error) {
    Serial.println("[ERROR] Invalid JSON from LoRa: " + message);
    return;
  }
  
  // Check if message is for this node
  if (doc.containsKey("receiver_id")) {
    String receiverId = doc["receiver_id"];
    
    if (receiverId == "all" || receiverId == nodeId) {
      // Forward message to Bluetooth (Flutter app)
      forwardMessageToBluetooth(doc);
      
      // Log message
      String senderName = doc["sender_name"] | "Unknown";
      String senderId = doc["sender_id"] | "Unknown";
      String messageText = doc["message"] | "";
      String timestamp = doc["timestamp"] | "";
      
      if (receiverId == "all") {
        Serial.println("[GROUP] " + senderName + " (" + senderId + "): " + messageText);
      } else {
        Serial.println("[PRIVATE] From " + senderName + " → To " + nodeId + ": " + messageText);
      }
    }
  }
}

// ============================================================================
// AUTHENTICATION FUNCTIONS
// ============================================================================

void sendAuthRequest() {
  Serial.println("[AUTH] Sending authentication request...");
  
  DynamicJsonDocument doc(256);
  doc["auth_request"] = true;
  doc["mac"] = nodeMac;
  doc["node_id"] = nodeId;
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  sendBluetoothMessage(jsonString);
}

void handleAuthConfirmation(DynamicJsonDocument& doc) {
  if (doc.containsKey("firstname") && doc.containsKey("mac")) {
    userName = doc["firstname"].as<String>();
    String receivedMac = doc["mac"].as<String>();
    
    // Verify MAC matches
    if (receivedMac == nodeMac) {
      isAuthenticated = true;
      
      // Save user data to Preferences
      preferences.putString("user_name", userName);
      preferences.putString("node_mac", nodeMac);
      preferences.putString("node_id", nodeId);
      preferences.putBool("is_authenticated", true);
      
      Serial.println("[SYNC] User authenticated: " + userName + " (" + nodeId + ")");
      
      // Send sync confirmation
      DynamicJsonDocument responseDoc(256);
      responseDoc["sync_complete"] = true;
      responseDoc["node_id"] = nodeId;
      responseDoc["user_name"] = userName;
      
      String responseJson;
      serializeJson(responseDoc, responseJson);
      sendBluetoothMessage(responseJson);
      
    } else {
      Serial.println("[ERROR] MAC address mismatch in authentication!");
    }
  }
}

void loadStoredUserData() {
  userName = preferences.getString("user_name", "");
  String storedMac = preferences.getString("node_mac", "");
  String storedNodeId = preferences.getString("node_id", "");
  isAuthenticated = preferences.getBool("is_authenticated", false);
  
  if (userName != "" && storedMac == nodeMac && storedNodeId == nodeId) {
    Serial.println("[INFO] Loaded stored user data: " + userName + " (" + nodeId + ")");
  } else {
    Serial.println("[INFO] No valid stored user data found");
    isAuthenticated = false;
  }
}

// ============================================================================
// MESSAGE HANDLING FUNCTIONS
// ============================================================================

void handleGroupMessage(DynamicJsonDocument& doc) {
  Serial.println("[GROUP] Broadcasting message via LoRa...");
  
  // Send via LoRa
  sendLoRaMessage(doc);
  
  // Log locally
  String senderName = doc["sender_name"] | "Unknown";
  String messageText = doc["message"] | "";
  Serial.println("[GROUP] " + senderName + " (" + nodeId + "): " + messageText);
}

void handlePrivateMessage(DynamicJsonDocument& doc) {
  String receiverId = doc["receiver_id"] | "";
  
  if (receiverId != "") {
    Serial.println("[PRIVATE] Sending private message to: " + receiverId);
    
    // Send via LoRa
    sendLoRaMessage(doc);
    
    // Log locally
    String senderName = doc["sender_name"] | "Unknown";
    String messageText = doc["message"] | "";
    Serial.println("[PRIVATE] From " + senderName + " → To " + receiverId + ": " + messageText);
  }
}

void forwardMessageToBluetooth(DynamicJsonDocument& doc) {
  String jsonString;
  serializeJson(doc, jsonString);
  sendBluetoothMessage(jsonString);
}

// ============================================================================
// LORA TRANSMISSION
// ============================================================================

void sendLoRaMessage(DynamicJsonDocument& doc) {
  String jsonString;
  serializeJson(doc, jsonString);
  
  LoRa.beginPacket();
  LoRa.print(jsonString);
  LoRa.endPacket();
  
  Serial.println("[LORA] Sent: " + jsonString);
}

// ============================================================================
// BLUETOOTH TRANSMISSION
// ============================================================================

void sendBluetoothMessage(String message) {
  if (SerialBT.hasClient()) {
    SerialBT.println(message);
    Serial.println("[BT] Sent: " + message);
  } else {
    Serial.println("[ERROR] No Bluetooth client connected!");
  }
}

// ============================================================================
// CONNECTION MANAGEMENT
// ============================================================================

void handleConnectionRetry() {
  if (!bluetoothConnected && (millis() - lastConnectionAttempt > CONNECTION_RETRY_INTERVAL)) {
    lastConnectionAttempt = millis();
    Serial.println("[BT] Attempting to reconnect...");
    
    // Bluetooth will auto-reconnect if client is available
  }
}

void sendHeartbeat() {
  if (isAuthenticated && bluetoothConnected && (millis() - lastHeartbeat > HEARTBEAT_INTERVAL)) {
    lastHeartbeat = millis();
    
    DynamicJsonDocument heartbeatDoc(256);
    heartbeatDoc["heartbeat"] = true;
    heartbeatDoc["node_id"] = nodeId;
    heartbeatDoc["timestamp"] = millis();
    
    String heartbeatJson;
    serializeJson(heartbeatDoc, heartbeatJson);
    sendBluetoothMessage(heartbeatJson);
    
    Serial.println("[HEARTBEAT] Sent heartbeat");
  }
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

String getCurrentTimestamp() {
  // Simple timestamp since we don't have RTC
  unsigned long seconds = millis() / 1000;
  unsigned long minutes = seconds / 60;
  unsigned long hours = minutes / 60;
  
  seconds = seconds % 60;
  minutes = minutes % 60;
  hours = hours % 24;
  
  String timestamp = String(hours) + ":" + 
                    (minutes < 10 ? "0" : "") + String(minutes) + ":" + 
                    (seconds < 10 ? "0" : "") + String(seconds);
  
  return timestamp;
}

// ============================================================================
// END OF FILE
// ============================================================================
