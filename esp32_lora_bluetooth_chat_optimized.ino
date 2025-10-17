/*
 * ESP32 LoRa Bluetooth Chat - OPTIMIZED for WROOM32
 * Compressed version with core functionality only
 * 
 * Hardware: ESP32 → SX1278
 * GPIO5→NSS, GPIO23→MOSI, GPIO19→MISO, GPIO18→SCK, GPIO2→RST, GPIO4→DIO0
 */

#include <BluetoothSerial.h>
#include <SPI.h>
#include <LoRa.h>
#include <WiFi.h>

// ============================================================================
// CONFIG
// ============================================================================
#define LORA_NSS 5
#define LORA_RST 2
#define LORA_DIO0 4
#define LORA_FREQ 433E6
#define BT_NAME "ESP32_LoRa_Node"

BluetoothSerial SerialBT;
String nodeId, nodeMac, userName, msgBuffer;
bool isAuth = false, btConn = false;

// ============================================================================
// SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n=== ESP32 LoRa Chat ===");
  
  // Get MAC for Node ID
  WiFi.mode(WIFI_STA);
  nodeMac = WiFi.macAddress();
  nodeId = "ESP32_" + nodeMac.substring(12);
  nodeId.replace(":", "");
  
  Serial.println("Node: " + nodeId);
  
  // Init LoRa
  LoRa.setPins(LORA_NSS, LORA_RST, LORA_DIO0);
  if (!LoRa.begin(LORA_FREQ)) {
    Serial.println("LoRa FAILED!");
    while(1) delay(1000);
  }
  LoRa.setTxPower(20);
  LoRa.setSpreadingFactor(7);
  LoRa.setSignalBandwidth(125E3);
  LoRa.onReceive(onLoRaRx);
  LoRa.receive();
  Serial.println("LoRa OK");
  
  // Init Bluetooth
  if (!SerialBT.begin(BT_NAME)) {
    Serial.println("BT FAILED!");
    return;
  }
  Serial.println("BT Ready: " + String(BT_NAME));
  Serial.println("===================");
}

// ============================================================================
// LOOP
// ============================================================================
void loop() {
  handleBT();
  delay(10);
}

// ============================================================================
// BLUETOOTH HANDLER
// ============================================================================
void handleBT() {
  // Connection check
  if (SerialBT.hasClient()) {
    if (!btConn) {
      btConn = true;
      Serial.println("[BT] Connected!");
      if (!isAuth) sendAuth();
    }
    
    // Read messages
    while (SerialBT.available()) {
      char c = SerialBT.read();
      if (c == '\n') {
        processMsg(msgBuffer);
        msgBuffer = "";
      } else {
        msgBuffer += c;
      }
    }
  } else {
    if (btConn) {
      btConn = false;
      isAuth = false;
      Serial.println("[BT] Disconnected");
    }
  }
}

// ============================================================================
// MESSAGE PROCESSING
// ============================================================================
void processMsg(String msg) {
  Serial.println("[RX] " + msg);
  
  // Simple JSON parsing (no library needed)
  if (msg.indexOf("\"auth_confirm\":true") > 0) {
    // Extract firstname
    int nameStart = msg.indexOf("\"firstname\":\"") + 13;
    int nameEnd = msg.indexOf("\"", nameStart);
    if (nameStart > 12 && nameEnd > nameStart) {
      userName = msg.substring(nameStart, nameEnd);
      isAuth = true;
      Serial.println("[AUTH] User: " + userName);
      
      // Send sync complete
      String sync = "{\"sync_complete\":true,\"node_id\":\"" + nodeId + 
                    "\",\"user_name\":\"" + userName + "\"}";
      SerialBT.println(sync);
      Serial.println("[SYNC] Complete");
    }
  }
  else if (msg.indexOf("\"type\":\"group\"") > 0 || msg.indexOf("\"type\":\"private\"") > 0) {
    // Forward to LoRa
    LoRa.beginPacket();
    LoRa.print(msg);
    LoRa.endPacket();
    Serial.println("[LORA] Sent");
    
    // Log
    int msgStart = msg.indexOf("\"message\":\"") + 11;
    int msgEnd = msg.indexOf("\"", msgStart);
    if (msgStart > 10 && msgEnd > msgStart) {
      String msgText = msg.substring(msgStart, msgEnd);
      Serial.println("[MSG] " + msgText);
    }
  }
}

// ============================================================================
// LORA HANDLER
// ============================================================================
void onLoRaRx(int packetSize) {
  if (packetSize == 0) return;
  
  String data = "";
  while (LoRa.available()) {
    data += (char)LoRa.read();
  }
  
  Serial.println("[LORA] RX: " + data);
  
  // Check if for this node
  if (data.indexOf("\"receiver_id\":\"all\"") > 0 || 
      data.indexOf("\"receiver_id\":\"" + nodeId + "\"") > 0) {
    // Forward to Bluetooth
    if (btConn) {
      SerialBT.println(data);
      Serial.println("[BT] Forwarded");
    }
  }
}

// ============================================================================
// AUTH REQUEST
// ============================================================================
void sendAuth() {
  String auth = "{\"auth_request\":true,\"mac\":\"" + nodeMac + 
                "\",\"node_id\":\"" + nodeId + "\"}";
  SerialBT.println(auth);
  Serial.println("[AUTH] Request sent");
}

// ============================================================================
// END
// ============================================================================
