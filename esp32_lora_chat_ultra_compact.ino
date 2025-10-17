/*
 * ESP32 LoRa Chat - ULTRA COMPACT for WROOM32
 * Optimized to fit in 1.25MB flash limit
 * 
 * Wiring: GPIO5→NSS, GPIO23→MOSI, GPIO19→MISO, GPIO18→SCK, GPIO2→RST, GPIO4→DIO0
 */

#include <BluetoothSerial.h>
#include <LoRa.h>

// Hardware pins
#define NSS 5
#define RST 2
#define DIO0 4

BluetoothSerial BT;
String nId, uName, buf;
bool auth = false, conn = false;

void setup() {
  Serial.begin(115200);
  
  // Node ID from chip
  uint64_t c = ESP.getEfuseMac();
  nId = "ESP32_" + String((uint32_t)(c >> 32), HEX);
  nId.toUpperCase();
  
  // Init LoRa
  LoRa.setPins(NSS, RST, DIO0);
  if (!LoRa.begin(433E6)) {
    Serial.println("LoRa FAIL");
    while(1) delay(1000);
  }
  LoRa.setTxPower(20);
  LoRa.setSpreadingFactor(7);
  
  // Init BT
  BT.begin("ESP32_LoRa_Chat");
  
  Serial.println("Ready: " + nId);
}

void loop() {
  // BT connection check
  if (BT.hasClient()) {
    if (!conn) {
      conn = true;
      Serial.println("BT+");
      if (!auth) sendAuth();
    }
    
    // Read BT
    while (BT.available()) {
      char c = BT.read();
      if (c == '\n') {
        process(buf);
        buf = "";
      } else if (buf.length() < 512) {
        buf += c;
      }
    }
  } else if (conn) {
    conn = false;
    auth = false;
    Serial.println("BT-");
  }
  
  // Read LoRa
  int sz = LoRa.parsePacket();
  if (sz) {
    String msg = "";
    while (LoRa.available() && msg.length() < 512) {
      msg += (char)LoRa.read();
    }
    Serial.println("LoRa: " + msg);
    
    // Forward to BT if for us
    if (msg.indexOf("\"all\"") > 0 || msg.indexOf(nId) > 0) {
      if (conn) BT.println(msg);
    }
  }
  
  delay(10);
}

void sendAuth() {
  String m = "{\"auth_request\":true,\"node_id\":\"" + nId + "\"}";
  BT.println(m);
  Serial.println("Auth>");
}

void process(String m) {
  Serial.println("RX: " + m);
  
  // Auth confirm
  if (m.indexOf("\"auth_confirm\":true") > 0) {
    int s = m.indexOf("\"firstname\":\"") + 13;
    int e = m.indexOf("\"", s);
    if (s > 12 && e > s) {
      uName = m.substring(s, e);
      auth = true;
      Serial.println("User: " + uName);
      
      String r = "{\"sync_complete\":true,\"node_id\":\"" + nId + "\"}";
      BT.println(r);
    }
  }
  // Chat message
  else if (m.indexOf("\"type\":") > 0 && auth) {
    LoRa.beginPacket();
    LoRa.print(m);
    LoRa.endPacket();
    Serial.println("LoRa>");
  }
}

