/*
 * ESP32 NODE A - BLUETOOTH + LORA (NO AUTH - TESTING MODE)
 * Device Name: ESP32_Node_A
 * Optimized for ESP32 WROOM32
 * 
 * Wiring: GPIO5→NSS, GPIO23→MOSI, GPIO19→MISO, GPIO18→SCK, GPIO2→RST, GPIO4→DIO0
 */

#include <BluetoothSerial.h>
#include <LoRa.h>

// LoRa pins
#define NSS 5
#define RST 2
#define DIO0 4
#define FREQ 433E6

// Unique device name for Node A
#define BT_DEVICE_NAME "ESP32_Node_A"

BluetoothSerial BT;
String nId = "";
String buf = "";
bool conn = false;
unsigned long lastCheck = 0;

void setup() {
  Serial.begin(115200);
  delay(500);
  
  // Node ID from chip
  uint64_t c = ESP.getEfuseMac();
  nId = "NodeA_" + String((uint32_t)(c >> 32), HEX);
  nId.toUpperCase();
  
  Serial.println("\n=== ESP32 NODE A - BT+LoRa ===");
  Serial.print("Device Name: ");
  Serial.println(BT_DEVICE_NAME);
  Serial.print("Node ID: ");
  Serial.println(nId);
  
  // Init LoRa
  LoRa.setPins(NSS, RST, DIO0);
  if (!LoRa.begin(FREQ)) {
    Serial.println("[ERROR] LoRa initialization failed!");
    while(1) {
      delay(1000);
      Serial.print(".");
    }
  }
  LoRa.setTxPower(20);
  LoRa.setSpreadingFactor(7);
  LoRa.setSignalBandwidth(125E3);
  LoRa.enableCrc();
  Serial.println("[OK] LoRa initialized (433 MHz)");
  
  // Init BT with unique name
  BT.begin(BT_DEVICE_NAME);
  Serial.print("[OK] Bluetooth ready: ");
  Serial.println(BT_DEVICE_NAME);
  Serial.println("[READY] Waiting for connection...\n");
}

void loop() {
  // Connection health check every 5 seconds
  if (millis() - lastCheck > 5000) {
    lastCheck = millis();
    if (conn && !BT.hasClient()) {
      // Client disconnected unexpectedly
      conn = false;
      Serial.println("\n[WARN] Client disconnected unexpectedly");
      Serial.println("[READY] Waiting for new connection...\n");
    }
  }
  
  // Check BT connection
  if (BT.hasClient()) {
    if (!conn) {
      conn = true;
      Serial.println("\n╔════════════════════════════════════════╗");
      Serial.println("║     BLUETOOTH CLIENT CONNECTED        ║");
      Serial.println("╚════════════════════════════════════════╝");
      Serial.print("[INFO] Device Name: ");
      Serial.println(BT_DEVICE_NAME);
      Serial.print("[INFO] Node ID: ");
      Serial.println(nId);
      
      // Send ready status
      BT.println("{\"status\":\"connected\",\"node_id\":\"" + nId + "\",\"device\":\"" + String(BT_DEVICE_NAME) + "\"}");
      Serial.println("[SENT] Ready status to app\n");
    }
    
    // Read from BT with buffer protection
    while (BT.available()) {
      char c = BT.read();
      
      if (c == '\n' || c == '\r') {
        if (buf.length() > 0) {
          handleBT(buf);
          buf = "";
        }
      } else if (buf.length() < 512) {
        buf += c;
      } else {
        // Buffer overflow protection
        Serial.println("[WARN] Buffer overflow, clearing");
        buf = "";
      }
    }
  } else {
    // Handle disconnection
    if (conn) {
      conn = false;
      Serial.println("\n[INFO] Client disconnected normally");
      Serial.println("[READY] Waiting for new connection...\n");
    }
  }
  
  // Read from LoRa
  int sz = LoRa.parsePacket();
  if (sz > 0) {
    String msg = "";
    while (LoRa.available() && msg.length() < 512) {
      msg += (char)LoRa.read();
    }
    
    int rssi = LoRa.packetRssi();
    float snr = LoRa.packetSnr();
    
    Serial.println("╔═══════════════════════════════════════════╗");
    Serial.println("║ [LoRa RX] ← INCOMING MESSAGE");
    Serial.print("║ [RSSI] ");
    Serial.print(rssi);
    Serial.print(" dBm | [SNR] ");
    Serial.print(snr);
    Serial.println(" dB");
    Serial.print("║ [DATA] ");
    Serial.println(msg);
    
    // CHECK IF MESSAGE IS FROM THIS NODE (ignore own messages)
    bool isFromSelf = false;
    if (msg.indexOf("\"from_node\":\"" + nId + "\"") > 0) {
      isFromSelf = true;
      Serial.println("║ [FILTER] ⚠️  OWN MESSAGE - IGNORED (no loopback)");
    }
    
    // Forward to BT only if NOT from self
    if (!isFromSelf && conn && BT.hasClient()) {
      BT.println(msg);
      Serial.println("║ [LoRa→BT] ✓ FORWARDED to app");
      
      // Extract and display message content
      int msgStart = msg.indexOf("\"message\":\"") + 11;
      int msgEnd = msg.indexOf("\"", msgStart);
      if (msgStart > 10 && msgEnd > msgStart) {
        String msgContent = msg.substring(msgStart, msgEnd);
        Serial.print("║ [CONTENT] ");
        Serial.println(msgContent);
      }
      
    } else if (isFromSelf) {
      Serial.println("║ [LoRa→BT] Skipped (own message)");
    } else {
      Serial.println("║ [LoRa→BT] Not forwarded (no BT client)");
    }
    
    Serial.println("╚═══════════════════════════════════════════╝");
    Serial.println();
  }
  
  delay(10);
}

void handleBT(String m) {
  Serial.println("╔═══════════════════════════════════════════╗");
  Serial.print("║ [BT RX] ");
  Serial.println(m);
  
  // Send acknowledgment to app immediately
  if (conn && BT.hasClient()) {
    BT.println("{\"ack\":\"received\"}");
    Serial.println("║ [ACK] Sent to app");
  }
  
  // Check if it's a chat message
  if (m.indexOf("\"type\":") > 0 && m.indexOf("\"message\":") > 0) {
    // Extract message content for logging
    int msgStart = m.indexOf("\"message\":\"") + 11;
    int msgEnd = m.indexOf("\"", msgStart);
    String msgContent = "";
    if (msgStart > 10 && msgEnd > msgStart) {
      msgContent = m.substring(msgStart, msgEnd);
    }
    
    Serial.print("║ [MSG] Content: ");
    Serial.println(msgContent);
    
    // ADD NODE ID TO MESSAGE (so other nodes know who sent it)
    String loraMsg = "";
    int lastBrace = m.lastIndexOf("}");
    if (lastBrace > 0) {
      loraMsg = m.substring(0, lastBrace);
      loraMsg += ",\"from_node\":\"" + nId + "\"}";
    } else {
      loraMsg = m; // fallback
    }
    
    // Transmit via LoRa with confirmation
    Serial.println("║ [LoRa TX] ➤ Broadcasting...");
    
    LoRa.beginPacket();
    LoRa.print(loraMsg);
    bool txSuccess = LoRa.endPacket();
    
    if (txSuccess) {
      Serial.print("║ [LoRa TX] ✓ SUCCESS (");
      Serial.print(loraMsg.length());
      Serial.println(" bytes)");
    } else {
      Serial.println("║ [LoRa TX] ✗ FAILED!");
    }
    
    Serial.print("║ [LoRa TX] Data: ");
    Serial.println(loraMsg);
    
  } else {
    Serial.println("║ [BT RX] Non-message data (ignored)");
  }
  
  Serial.println("╚═══════════════════════════════════════════╝");
  Serial.println();
}

