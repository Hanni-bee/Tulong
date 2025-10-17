/*
 * TULONG Hardware Firmware
 * ESP32 WROOM 32 + SX1278 LoRa Module
 * 
 * This firmware acts as a bridge between the mobile app and LoRa radio.
 * All controls come from the mobile app via USB serial.
 */

#include <SPI.h>
#include <LoRa.h>

// LoRa pins for ESP32
#define LORA_SCK     5    // GPIO5  - SCK
#define LORA_MISO   19    // GPIO19 - MISO
#define LORA_MOSI   27    // GPIO27 - MOSI
#define LORA_CS     18    // GPIO18 - CS
#define LORA_RST    14    // GPIO14 - RST
#define LORA_DIO0    26   // GPIO26 - DIO0

// LoRa frequency
#define LORA_FREQUENCY 433E6  // 433MHz

// Device info
#define DEVICE_NAME "TULONG_ESP32"
#define FIRMWARE_VERSION "1.0.0"

// Communication states
bool loraConnected = false;
bool isTransmitting = false;

// Battery monitoring (if connected)
const int batteryPin = 34; // ADC pin for battery
int batteryLevel = 100;

void setup() {
  // Initialize Serial communication with phone
  Serial.begin(115200);
  while (!Serial);
  
  Serial.println("STATUS:Initializing TULONG Hardware...");
  
  // Initialize SPI
  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_CS);
  
  // Initialize LoRa
  LoRa.setPins(LORA_CS, LORA_RST, LORA_DIO0);
  
  if (!LoRa.begin(LORA_FREQUENCY)) {
    Serial.println("LORA:ERROR");
    Serial.println("STATUS:LoRa initialization failed!");
    while (1);
  }
  
  // Configure LoRa settings
  LoRa.setSpreadingFactor(12);     // SF12 for long range
  LoRa.setSignalBandwidth(125E3);  // 125 kHz bandwidth
  LoRa.setCodingRate4(8);          // 4/8 coding rate
  LoRa.setTxPower(20);             // 20 dBm (100mW)
  LoRa.enableCrc();                // Enable CRC
  
  // Set up receive callback
  LoRa.onReceive(onLoRaReceive);
  LoRa.receive(); // Start listening
  
  loraConnected = true;
  Serial.println("LORA:CONNECTED");
  
  // Send device info
  sendDeviceInfo();
  
  Serial.println("STATUS:TULONG Hardware Ready!");
}

void loop() {
  // Check for commands from phone via Serial
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    processCommand(command);
  }
  
  // Update battery level periodically
  static unsigned long lastBatteryCheck = 0;
  if (millis() - lastBatteryCheck > 5000) { // Every 5 seconds
    updateBatteryLevel();
    lastBatteryCheck = millis();
  }
  
  // Update signal strength periodically
  static unsigned long lastSignalCheck = 0;
  if (millis() - lastSignalCheck > 2000) { // Every 2 seconds
    updateSignalStrength();
    lastSignalCheck = millis();
  }
}

// Process commands from mobile app
void processCommand(String command) {
  Serial.print("DEBUG:Received command: ");
  Serial.println(command);
  
  if (command == "INIT") {
    sendDeviceInfo();
  }
  else if (command == "PTT_START") {
    startTransmission();
  }
  else if (command == "PTT_STOP") {
    stopTransmission();
  }
  else if (command.startsWith("LORA_SEND:")) {
    String message = command.substring(10); // Remove "LORA_SEND:" prefix
    sendLoRaMessage(message);
  }
  else if (command.startsWith("EMERGENCY:")) {
    String emergencyData = command.substring(10);
    sendEmergencySignal(emergencyData);
  }
  else if (command == "STATUS") {
    sendDeviceInfo();
  }
  else {
    Serial.println("ERROR:Unknown command");
  }
}

// Send device information to phone
void sendDeviceInfo() {
  String info = "STATUS:NAME=" + String(DEVICE_NAME) + 
                ",FW=" + String(FIRMWARE_VERSION) +
                ",BAT=" + String(batteryLevel) +
                ",SIG=" + String(LoRa.packetRssi());
  Serial.println(info);
}

// Start voice transmission
void startTransmission() {
  if (!loraConnected) {
    Serial.println("ERROR:LoRa not connected");
    return;
  }
  
  isTransmitting = true;
  Serial.println("LORA:TRANSMITTING");
  Serial.println("STATUS:Ready to transmit audio");
  
  // Note: Audio data will come as separate packets via Serial
  // Format: AUDIO:base64_encoded_data
}

// Stop voice transmission
void stopTransmission() {
  isTransmitting = false;
  LoRa.receive(); // Back to receive mode
  Serial.println("LORA:CONNECTED");
  Serial.println("STATUS:Transmission stopped");
}

// Send LoRa message
void sendLoRaMessage(String message) {
  if (!loraConnected) {
    Serial.println("ERROR:LoRa not connected");
    return;
  }
  
  Serial.print("DEBUG:Sending LoRa message: ");
  Serial.println(message);
  
  LoRa.beginPacket();
  LoRa.print("MSG:");
  LoRa.print(message);
  LoRa.endPacket();
  
  LoRa.receive(); // Back to receive mode
  
  Serial.println("STATUS:Message sent via LoRa");
}

// Send emergency signal
void sendEmergencySignal(String emergencyData) {
  if (!loraConnected) {
    Serial.println("ERROR:LoRa not connected");
    return;
  }
  
  Serial.print("DEBUG:Sending emergency signal: ");
  Serial.println(emergencyData);
  
  // Send emergency signal multiple times for reliability
  for (int i = 0; i < 3; i++) {
    LoRa.beginPacket();
    LoRa.print("EMERGENCY:");
    LoRa.print(emergencyData);
    LoRa.endPacket();
    delay(100);
  }
  
  LoRa.receive(); // Back to receive mode
  
  Serial.println("STATUS:Emergency signal sent");
}

// Callback when LoRa packet is received
void onLoRaReceive(int packetSize) {
  if (packetSize == 0) return;
  
  Serial.println("LORA:RECEIVING");
  
  String received = "";
  while (LoRa.available()) {
    received += (char)LoRa.read();
  }
  
  int rssi = LoRa.packetRssi();
  float snr = LoRa.packetSnr();
  
  Serial.print("MESSAGE:");
  Serial.println(received);
  Serial.print("SIGNAL:");
  Serial.println(rssi);
  
  // Check if it's an emergency signal
  if (received.startsWith("EMERGENCY:")) {
    Serial.print("EMERGENCY:");
    Serial.println(received.substring(10));
  }
  
  // Back to connected state
  Serial.println("LORA:CONNECTED");
}

// Update battery level
void updateBatteryLevel() {
  // Read battery voltage (adjust based on your circuit)
  int adcValue = analogRead(batteryPin);
  float voltage = (adcValue / 4095.0) * 3.3 * 2; // Assuming voltage divider
  
  // Convert to percentage (adjust based on your battery)
  // Li-ion: 4.2V = 100%, 3.0V = 0%
  batteryLevel = map(voltage * 100, 300, 420, 0, 100);
  batteryLevel = constrain(batteryLevel, 0, 100);
  
  Serial.print("BATTERY:");
  Serial.println(batteryLevel);
}

// Update signal strength
void updateSignalStrength() {
  int rssi = LoRa.packetRssi();
  
  // Convert RSSI to signal strength percentage
  // Typical range: -120 dBm (weak) to -30 dBm (strong)
  int signalStrength = map(rssi, -120, -30, 0, 100);
  signalStrength = constrain(signalStrength, 0, 100);
  
  Serial.print("SIGNAL:");
  Serial.println(signalStrength);
}

