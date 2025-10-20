/*
 * ESP32 NODE B - 4MB FLASH OPTIMIZED
 * Device: ESP32 WROOM32 (4MB Flash)
 * Device Name: ESP32_Node_B
 * 
 * OPTIMIZED FOR 4MB FLASH:
 * - Minimal memory usage
 * - No external libraries beyond essentials
 * - Compact JSON handling
 * - Efficient LoRa communication
 * 
 * Wiring: GPIO5→NSS, GPIO23→MOSI, GPIO19→MISO, GPIO18→SCK, GPIO2→RST, GPIO4→DIO0
 */

#include <BluetoothSerial.h>
#include <LoRa.h>

// LoRa pins
#define NSS 5
#define RST 2
#define DIO0 4
#define FREQ 434.42E6  // 434.42 MHz (different from Node A)

// Device name
#define BT_DEVICE_NAME "ESP32_Node_B"

BluetoothSerial BT;
String nId = "";
String buf = "";
bool conn = false;
unsigned long lastCheck = 0;
unsigned long lastPresence = 0;

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
  Serial.println("Frequency: 434.42 MHz");
  
  // Init LoRa
  LoRa.setPins(NSS, RST, DIO0);
  if (!LoRa.begin(FREQ)) {
    Serial.println("[ERROR] LoRa failed!");
    while(1) delay(1000);
  }
  LoRa.setTxPower(20);
  LoRa.setSpreadingFactor(7);
  LoRa.setSignalBandwidth(125E3);
  LoRa.enableCrc();
  Serial.println("[OK] LoRa ready");
  
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
    
    while (BT.available()) {
      char c = BT.read();
      if (c == '\n' || c == '\r') {
        if (buf.length() > 0) {
          handleBT(buf);
          buf = "";
        }
      } else if (buf.length() < 256) { // Smaller buffer
        buf += c;
      } else {
        buf = ""; // Clear on overflow
      }
    }
  } else {
    if (conn) {
      conn = false;
      Serial.println("[BT] Client disconnected");
    }
  }
  
  // Handle LoRa
  int sz = LoRa.parsePacket();
  if (sz > 0) {
    String msg = "";
    while (LoRa.available() && msg.length() < 256) {
      msg += (char)LoRa.read();
    }
    
    int rssi = LoRa.packetRssi();
    Serial.println("[LoRa] RX: " + msg + " (RSSI: " + String(rssi) + ")");
    
    // Parse and handle message
    handleLoRa(msg, rssi);
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

void handleLoRa(String msg, int rssi) {
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
      Serial.println("[LoRa→BT] Forwarded");
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
  // Add from_node to message
  String loraMsg = msg;
  if (loraMsg.endsWith("}")) {
    loraMsg = loraMsg.substring(0, loraMsg.length() - 1);
    loraMsg += ",\"from_node\":\"" + nId + "\"}";
  }
  
  // Send via LoRa
  LoRa.beginPacket();
  LoRa.print(loraMsg);
  LoRa.endPacket();
  
  Serial.println("[LoRa] TX: " + loraMsg);
}

void broadcastPresence() {
  String presence = "{\"presence\":true,\"node_id\":\"" + nId + "\",\"user_name\":\"NodeB_User\",\"frequency\":434420000}";
  
  LoRa.beginPacket();
  LoRa.print(presence);
  LoRa.endPacket();
  
  Serial.println("[PRESENCE] Broadcasted");
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
  // Only support 434.42 MHz for simplicity
  if (newFreq == 434420000) {
    Serial.println("[FREQ] Already on 434.42 MHz");
    if (conn) BT.println("{\"frequency_changed\":true}");
  } else {
    Serial.println("[FREQ] Only 434.42 MHz supported");
  }
}

void sendStatus() {
  String status = "{\"status\":\"connected\",\"node_id\":\"" + nId + "\",\"frequency\":434420000}";
  BT.println(status);
  Serial.println("[STATUS] Sent");
}
