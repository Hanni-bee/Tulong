/*
 * ESP32 NODE B - BLUETOOTH + LORA (NO AUTH - TESTING MODE)
 * Device Name: ESP32_Node_B
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

// Unique device name for Node B
#define BT_DEVICE_NAME "ESP32_Node_B"

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
  nId = "NodeB_" + String((uint32_t)(c >> 32), HEX);
  nId.toUpperCase();
  
  Serial.println("\n=== ESP32 NODE B - BT+LoRa ===");
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
    
    Serial.print("[LoRa RX] RSSI: ");
    Serial.print(rssi);
    Serial.print(" dBm, SNR: ");
    Serial.print(snr);
    Serial.println(" dB");
    Serial.print("[LoRa RX] Data: ");
    Serial.println(msg);
    
    // Forward to BT if connected
    if (conn && BT.hasClient()) {
      BT.println(msg);
      Serial.println("[LoRa→BT] Forwarded to app");
    } else {
      Serial.println("[LoRa→BT] Not forwarded (no client)");
    }
    
    Serial.println();
  }
  
  delay(10);
}

void handleBT(String m) {
  Serial.print("[BT RX] ");
  Serial.println(m);
  
  // Send acknowledgment
  if (conn && BT.hasClient()) {
    BT.println("{\"ack\":\"received\"}");
  }
  
  // Check if it's a chat message
  if (m.indexOf("\"type\":") > 0 && m.indexOf("\"message\":") > 0) {
    // Extract message for logging
    int msgStart = m.indexOf("\"message\":\"") + 11;
    int msgEnd = m.indexOf("\"", msgStart);
    String msgContent = "";
    if (msgStart > 10 && msgEnd > msgStart) {
      msgContent = m.substring(msgStart, msgEnd);
    }
    
    // Transmit via LoRa
    Serial.println("[LoRa TX] Transmitting...");
    LoRa.beginPacket();
    LoRa.print(m);
    LoRa.endPacket();
    
    Serial.print("[LoRa TX] Success (");
    Serial.print(m.length());
    Serial.println(" bytes)");
    if (msgContent.length() > 0) {
      Serial.print("[LoRa TX] Message: ");
      Serial.println(msgContent);
    }
    Serial.println();
  } else {
    Serial.println("[BT RX] Non-message data (ignored for LoRa)");
    Serial.println();
  }
}

