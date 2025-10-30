## Tulong: Offline LoRa Mesh + Bluetooth PTT System – Technical Setup and Inline Documentation

### Project Description
Tulong is a Flutter-based Android application that integrates with ESP32 (WROOM32) nodes equipped with SX1278 LoRa radios to provide offline, low-power communication. The system uses Bluetooth Classic (SPP) to bridge the phone app to an ESP32 node, and LoRa for long-range radio messaging between ESP32 nodes. It supports text chat, group/private messaging, and a voice push-to-talk (PTT) pathway via PCM16LE frames designed for ADPCM compression on the ESP32 side. Firebase (functions and rules) exists in the workspace for optional cloud features but the LoRa flow is designed to work completely offline.


## Current Setup

### Hardware
- ESP32-WROOM32 boards
- SX1278 LoRa (RA-02) modules, 433 MHz
- Phone: Android device with Bluetooth Classic

Key wiring (common in firmware):
```
ESP32 → SX1278
GPIO5  → NSS (CS)
GPIO23 → MOSI
GPIO19 → MISO
GPIO18 → SCK
GPIO2  → RST
GPIO4  → DIO0
```

Hardware role: ESP32 acts as a radio modem controlled by the Flutter app.

Reference: `HARDWARE_INTEGRATION_ARCHITECTURE.md`, `FINAL_SYSTEM_SUMMARY.md`.

### Software/Dependencies
- Flutter 3.x (Android target; min Android 5.0, API 21)
- Android app permissions: Bluetooth, Location (required for BT Classic discovery on newer Android)
- ESP32 Arduino core; libraries include `BluetoothSerial`, `LoRa`, optional `ArduinoJson`, `Preferences`
- Optional Firebase (functions and rules present; not required for offline LoRa operation)

Flutter packages (subset; see `pubspec.yaml`):
- `flutter_sound` for audio capture/playback
- `permission_handler` for runtime mic permissions

### Environment and Build
- Android build via Gradle; project contains `android/app/build.gradle.kts`
- `build-apk.bat` for local automated builds on Windows
- Multiple guidance documents for setup, testing, and integration:
  - `COMPLETE_BLUETOOTH_LORA_GUIDE.md`
  - `ESP32_FIRMWARE_REFERENCE.md`
  - `FINAL_SYSTEM_SUMMARY.md`
  - `ESP32_SETUP_AND_TESTING_GUIDE.md`
  - `VOICE_INTEGRATION_GUIDE.md`


## Core Features and Workflow

### Bluetooth SPP Bridge
- Phone connects over Bluetooth Classic SPP to the ESP32 node.
- Authentication flow uses a lightweight, name-based identity (firstname) and node IDs.
- JSON-based protocol over the serial link.

### LoRa Mesh Messaging
- ESP32 nodes exchange text messages via LoRa at 433 MHz.
- Supports broadcast (group) and targeted (private) messages.
- JSON envelopes are forwarded between Bluetooth (phone) and LoRa (nodes).

### Voice PTT (Design and Integration Path)
- Flutter captures PCM16LE frames (8 kHz, mono) suitable for IMA ADPCM compression on ESP32.
- ESP32 compresses and forwards over LoRa in multiple packets with CRC; reassembly and playback are handled upon receipt.
- Message formats for voice are documented in `VOICE_INTEGRATION_GUIDE.md`.

High-level flow:
```
Flutter App → Bluetooth SPP → ESP32 → (ADPCM) → LoRa → Other ESP32 → Bluetooth SPP → Flutter App
```


## Key Functions and Responsibilities

### ESP32 Firmware (Arduino)
Primary firmware options: `esp32_lora_bluetooth_chat.ino` (complete), compact/optimized variants, and final integrated single-file builds.

- Initialization
  - LoRa setup: frequency, power, spreading factor, bandwidth, CRC, receive mode
  - Bluetooth Serial: device name, connection detection
  - Node identity: derives `nodeId` from chip MAC

- Data Handling
  - Bluetooth RX: parse JSON, authenticate, route to LoRa
  - LoRa RX: parse JSON, route to Bluetooth, support broadcast/private
  - Heartbeats and basic connection-state management

Representative functions (names may vary by variant):
- LoRa init and RX handling
- Bluetooth init and connection handling
- Message routing between interfaces

### Flutter App (Dart)
- `lib/controllers/voice_controller.dart`
  - Captures PCM16LE at 8 kHz, mono via `flutter_sound`
  - Produces ~100ms frames, base64-encodes, and emits frames via a stream for transport
  - Controls start/stop PTT, playback stubs, and error streams

- UI Screens
  - Chat and LoRa screens show connection status, message lists, and controls
  - Walkie-talkie and calls screens for voice/interaction workflows

- Providers/Services
  - Authentication provider for lightweight app auth
  - Bluetooth service (simple or integrated) responsible for serial transport and message routing


## Data Flow Between Modules/Devices

### Text Messaging
1. Flutter composes a JSON message (chat or control).
2. Message is sent over Bluetooth SPP to ESP32.
3. ESP32 validates/authenticates and forwards over LoRa as JSON.
4. Receiving ESP32 node examines `to` or broadcast flags and forwards to its connected phone via Bluetooth.
5. Flutter UI updates in real time.

### Voice PTT (Designed Path)
1. Flutter records PCM16LE frames (8 kHz, mono) at ~100ms intervals.
2. Frames are base64-encoded and packaged into JSON.
3. ESP32 receives frames, compresses to ADPCM, splits across LoRa packets with CRC.
4. Receiving node reassembles, decodes to PCM/WAV, and forwards back to Flutter for playback.


## Missing or TODO Sections Detected
- Full ADPCM encode/decode implementation on ESP32 is referenced in guides; specific finalized code may not be present in the `.ino` variants included here. Voice is documented and wired for integration, but ensure the chosen firmware variant contains the ADPCM pipeline if enabling live voice over LoRa.
- Ensure the Flutter Bluetooth service in use routes `voice_message` frames to/from `VoiceController` consistently with the documented JSON keys.
- Validate Android 12+ Bluetooth/Location permission handling and background connection behavior (some flows may require fine-tuning).
- Confirm release signing and Play Store requirements if distributing the APK.


## Technical Report Summary

### Identified Errors/Warnings (Potential/Observed)
- Android `android/app/build.gradle.kts` modified but not staged; build differences may exist locally.
- Bluetooth Classic SPP on Android 12+ often requires additional runtime permission flows (BLUETOOTH_CONNECT, BLUETOOTH_SCAN, and ACCESS_FINE_LOCATION) and clear user education; verify manifest and runtime handling.
- Voice flow: ensure compatible frame size, base64 payload limits, and chunking/reassembly to avoid buffer overruns at the ESP32 and serial layers (variants show 256–512 char limits in buffers).
- Some compact firmware variants cap message buffer sizes aggressively (e.g., 256/512 chars). Long JSON messages or base64 frames may be truncated. Choose the complete firmware for voice.

### Diagnostics to Debug
- Bluetooth Layer
  - Verify SPP pairing and service channel; use serial logs at 115200 baud on ESP32.
  - Confirm phone permissions and Bluetooth connection status indicators in-app.
- LoRa Layer
  - Validate frequency (433 MHz), TX power (20 dBm), SF (7–9), and bandwidth (125 kHz) settings match across nodes.
  - Check CRC enabled and that both ends parse JSON consistently.
- Voice Path
  - Confirm PCM16LE format (8 kHz, mono) from Flutter.
  - Measure frame sizes pre/post base64 to ensure they fit within chosen firmware limits.
  - Inspect ADPCM encode/decode output for audible artifacts; adjust frame duration if necessary.

### Suggested Fixes/Improvements
- Permissions/Platform
  - Audit and update Android 12+ Bluetooth and Location permission flows; add rationale dialogs and fallback UX.
  - Add a dedicated Bluetooth diagnostics screen with connect/reconnect controls and logs.
- Firmware
  - Use the full-feature firmware for voice; increase input buffer for base64 frames or stream-chunk them deterministically.
  - Implement ADPCM encoder/decoder and packetization with sequence numbers and CRC if not already present in the selected build.
- Protocol
  - Define a single JSON schema version and enforce it across app and firmware to reduce parsing errors.
  - Add explicit message types and max payload guidance; add integrity fields (checksum, sequence, total frames) for voice.
- App
  - Wire `VoiceController` streams into the active Bluetooth service and LoRa chat screen; add UI state for recording, sending, and playback.
  - Add retransmission and progress indicators for voice multi-packet flows.

### Code References
Existing firmware shows standard initialization and routing patterns (function names vary by variant):

ESP32 LoRa init and Bluetooth init examples:
```text
esp32_lora_bluetooth_chat.ino → initializeLoRa(), initializeBluetooth(), onLoRaReceive(), handleBluetoothCommunication()
esp32_lora_bluetooth_chat_optimized.ino → onLoRaRx, handleBT
esp32_lora_chat_ultra_compact.ino → sendAuth(), process()
```

Flutter voice controller core:
```text
lib/controllers/voice_controller.dart → initialize(), startPTT(), stopPTT(), voiceFrameStream
```


## PDF Export
This Markdown is structured for straightforward PDF export. You can export to PDF using your preferred method (e.g., VS Code/Cursor extension or tools like Pandoc). Example command if Pandoc is available:

```bash
pandoc TECHNICAL_SETUP_AND_DOCUMENTATION_REPORT.md \
  -o Tulong_Technical_Documentation.pdf \
  --from gfm --toc --pdf-engine=wkhtmltopdf
```

Title: The title reflects the overall outcome of an offline-ready LoRa mesh system with Bluetooth PTT bridging as designed and documented across the repository.


