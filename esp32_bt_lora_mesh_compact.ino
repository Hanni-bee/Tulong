/*
 * ESP32 WROOM32 - Bluetooth + LoRa Mesh Chat
 * Ultra-compact for limited flash
 * 
 * Wiring: GPIO5→NSS, GPIO23→MOSI, GPIO19→MISO, GPIO18→SCK, GPIO2→DIO0
 */

#include <BluetoothSerial.h>
#include <LoRa.h>

#define NSS 5
#define DIO0 2

BluetoothSerial BT;
String nId, uName, buf;
bool auth = false, conn = false;

void setup() {
  Serial.begin(115200);
  
  // Node ID
  uint64_t c = ESP.getEfuseMac();
  nId = String((uint32_t)(c >> 32), HEX);
  nId.toUpperCase();
  
  // LoRa init
  LoRa.setPins(NSS, -1, DIO0);
  if (!LoRa.begin(433E6)) {
    Serial.println("LoRa fail");
    while(1) delay(1000);
  }
  LoRa.setTxPower(20);
  LoRa.setSpreadingFactor(9);
  LoRa.setSignalBandwidth(125E3);
  LoRa.enableCrc();
  
  // Bluetooth init
  BT.begin("ESP32_" + nId);
  
  Serial.println("Node: " + nId);
}

void loop() {
  // BT connection
  if (BT.hasClient()) {
    if (!conn) {
      conn = true;
      Serial.println("BT+");
      if (!auth) {
        BT.println("{\"auth_request\":true,\"node_id\":\"" + nId + "\"}");
        Serial.println("Auth>");
      }
    }
    
    // Read BT
    while (BT.available()) {
      char c = BT.read();
      if (c == '\n') {
        procBT(buf);
        buf = "";
      } else if (buf.length() < 256) {
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
    String pkt = "";
    while (LoRa.available() && pkt.length() < 256) {
      pkt += (char)LoRa.read();
    }
    procLoRa(pkt);
  }
  
  delay(10);
}

// Process Bluetooth
void procBT(String m) {
  Serial.println("BT: " + m);
  
  // Auth confirm
  if (m.indexOf("\"auth_confirm\":true") > 0) {
    int s = m.indexOf("\"firstname\":\"") + 13;
    int e = m.indexOf("\"", s);
    if (s > 12 && e > s) {
      uName = m.substring(s, e);
      auth = true;
      Serial.println("U: " + uName);
      BT.println("{\"sync_complete\":true,\"node_id\":\"" + nId + "\"}");
    }
  }
  // Chat message
  else if (m.indexOf("\"type\":") > 0 && auth) {
    // Convert JSON to LoRa format: from:ID to:ID msg:text via:ID,
    String to = "all";
    String msg = "";
    
    int toIdx = m.indexOf("\"receiver_id\":\"") + 15;
    if (toIdx > 14) {
      int toEnd = m.indexOf("\"", toIdx);
      if (toEnd > toIdx) to = m.substring(toIdx, toEnd);
    }
    
    int msgIdx = m.indexOf("\"message\":\"") + 11;
    if (msgIdx > 10) {
      int msgEnd = m.indexOf("\"", msgIdx);
      if (msgEnd > msgIdx) msg = m.substring(msgIdx, msgEnd);
    }
    
    // Send via LoRa
    String pkt = "from:" + nId + "to:" + to + "msg:" + msg + "via:" + nId + ",";
    LoRa.beginPacket();
    LoRa.print(pkt);
    LoRa.endPacket();
    Serial.println("LoRa>");
  }
}

// Process LoRa
void procLoRa(String pkt) {
  int fIdx = pkt.indexOf("from:") + 5;
  int tIdx = pkt.indexOf("to:");
  int mIdx = pkt.indexOf("msg:");
  int vIdx = pkt.indexOf("via:");
  
  if (fIdx < 5 || tIdx < 0 || mIdx < 0) return;
  
  String fromId = pkt.substring(fIdx, tIdx);
  String toId = pkt.substring(tIdx + 3, mIdx);
  String msg = (vIdx > 0) ? pkt.substring(mIdx + 4, vIdx) : pkt.substring(mIdx + 4);
  String via = (vIdx > 0) ? pkt.substring(vIdx + 4) : "";
  
  // Avoid loop
  if (via.indexOf(nId) != -1) return;
  
  // For me?
  if (toId == nId || toId == "all") {
    Serial.println("From " + fromId + ": " + msg);
    
    // Forward to BT
    if (conn && auth) {
      String json = "{\"type\":\"group\",\"sender_name\":\"" + fromId + 
                    "\",\"message\":\"" + msg + "\",\"receiver_id\":\"" + toId + "\"}";
      BT.println(json);
      Serial.println("→BT");
    }
  } else {
    // Relay
    String newVia = via + nId + ",";
    String fwd = "from:" + fromId + "to:" + toId + "msg:" + msg + "via:" + newVia;
    LoRa.beginPacket();
    LoRa.print(fwd);
    LoRa.endPacket();
    Serial.println("Relay: " + fromId + "→" + toId);
  }
}

