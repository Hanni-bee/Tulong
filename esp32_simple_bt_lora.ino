/*
 * ESP32 SIMPLE BLUETOOTH + LORA (NO AUTH - TESTING MODE)
 * Optimized for ESP32 WROOM32 - Direct communication
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

BluetoothSerial BT;
String nId = "";
String buf = "";
bool conn = false;

void setup() {
  Serial.begin(115200);
  
  // Node ID from chip
  uint64_t c = ESP.getEfuseMac();
  nId = "ESP32_" + String((uint32_t)(c >> 32), HEX);
  nId.toUpperCase();
  
  Serial.println("\n=== ESP32 BT+LoRa Simple Mode ===");
  Serial.println("Node: " + nId);
  
  // Init LoRa
  LoRa.setPins(NSS, RST, DIO0);
  if (!LoRa.begin(FREQ)) {
    Serial.println("LoRa FAIL!");
    while(1) delay(1000);
  }
  LoRa.setTxPower(20);
  LoRa.setSpreadingFactor(7);
  Serial.println("LoRa OK");
  
  // Init BT
  BT.begin("ESP32_LoRa_Chat");
  Serial.println("BT Ready: ESP32_LoRa_Chat");
  Serial.println("Waiting for connection...\n");
}

void loop() {
  // Check BT connection
  if (BT.hasClient()) {
    if (!conn) {
      conn = true;
      Serial.println("\n[BT] Connected!");
      BT.println("{\"status\":\"ready\"}");
    }
    
    // Read from BT
    while (BT.available()) {
      char c = BT.read();
      if (c == '\n') {
        if (buf.length() > 0) {
          handleBT(buf);
          buf = "";
        }
      } else if (buf.length() < 256) {
        buf += c;
      }
    }
  } else if (conn) {
    conn = false;
    Serial.println("\n[BT] Disconnected");
  }
  
  // Read from LoRa
  int sz = LoRa.parsePacket();
  if (sz) {
    String msg = "";
    while (LoRa.available() && msg.length() < 256) {
      msg += (char)LoRa.read();
    }
    
    Serial.println("[LoRa] RX: " + msg);
    
    // Forward to BT if connected
    if (conn) {
      BT.println(msg);
      Serial.println("[LoRa] -> BT forwarded");
    }
  }
  
  delay(10);
}

void handleBT(String m) {
  Serial.println("[BT] RX: " + m);
  
  // Echo back to confirm
  if (conn) {
    BT.println("{\"echo\":\"received\"}");
  }
  
  // Check if it's a chat message
  if (m.indexOf("\"type\":") > 0) {
    // Transmit via LoRa
    LoRa.beginPacket();
    LoRa.print(m);
    LoRa.endPacket();
    Serial.println("[LoRa] TX: Success (" + String(m.length()) + " bytes)");
  }
}

