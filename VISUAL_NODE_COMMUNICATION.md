# Visual Guide: How Node A and Node B Communicate

## 🎯 Simple Overview

```
┌─────────────┐         Bluetooth          ┌─────────────┐
│   Phone A   │◄──────────────────────────►│  ESP32 Node A│
└─────────────┘                             └──────┬──────┘
                                                    │
                                              nRF24L01
                                              (2.4GHz RF)
                                                    │
┌─────────────┐                             ┌──────▼──────┐
│   Phone B   │◄──────────────────────────►│  ESP32 Node B│
└─────────────┘         Bluetooth          └─────────────┘
```

## 🔄 Detailed Message Flow

### Scenario 1: Phone A sends "Hello" to Phone B

```
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 1: Phone A → ESP32 Node A                                      │
├─────────────────────────────────────────────────────────────────────┤
│ Phone A sends JSON via Bluetooth:                                   │
│ {"type":"group", "message":"Hello", "is_emergency":false}           │
└─────────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 2: ESP32 Node A Processes                                      │
├─────────────────────────────────────────────────────────────────────┤
│ • Receives via SerialBT                                             │
│ • Parses JSON to extract message text: "Hello"                      │
│ • Prepares nRF24 packet:                                            │
│   - Type: VTYPE_TEXT (0xA0)                                         │
│   - Sequence: 0                                                     │
│   - Payload: "Hello" (5 bytes, fits in 1 packet)                   │
│   - CRC8: Calculated checksum                                       │
└─────────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 3: ESP32 Node A → ESP32 Node B (via nRF24L01)                 │
├─────────────────────────────────────────────────────────────────────┤
│ • Transmits on Channel 108 (2.508 GHz)                              │
│ • Sends to address[0] ("1Node")                                     │
│ • Packet structure: [0xA0|00|05|CRC|"Hello"]                       │
└─────────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 4: ESP32 Node B Receives                                       │
├─────────────────────────────────────────────────────────────────────┤
│ • Listens on address[0] ("1Node")                                   │
│ • Receives packet                                                   │
│ • Verifies CRC8: ✅ Valid                                           │
│ • Detects type VTYPE_TEXT (0xA0)                                    │
│ • Extracts message: "Hello"                                         │
│ • Reassembles (if multiple packets)                                 │
└─────────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 5: ESP32 Node B → Phone B                                      │
├─────────────────────────────────────────────────────────────────────┤
│ • Wraps message back into JSON:                                     │
│   {"type":"group", "message":"Hello", "is_emergency":false}        │
│ • Sends via SerialBT (Bluetooth)                                    │
└─────────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 6: Phone B Displays                                            │
├─────────────────────────────────────────────────────────────────────┤
│ Flutter app receives JSON, parses, and displays "Hello" in chat    │
└─────────────────────────────────────────────────────────────────────┘
```

### Scenario 2: Phone B sends Emergency/SOS "HELP!" to Phone A

```
Phone B → Node B → Node A → Phone A
    ↓        ↓        ↓        ↓
  JSON    VTYPE_   VTYPE_   JSON
         SOS(0xA1) SOS(0xA1) +flag
```

**Key Difference:** Emergency messages use packet type `VTYPE_SOS (0xA1)` instead of `VTYPE_TEXT (0xA0)`, allowing the receiving node to know it's an emergency message.

### Scenario 3: Phone A sends Voice Message to Phone B

```
1. Phone A: <VOICE_START>
   ↓
2. Node A: Checks if channel busy
   ↓ (if free)
3. Node A → Node B: VTYPE_START (0xD0) packet
   ↓
4. Phone A streams Base64 audio lines
   ↓
5. Node A: For each Base64 line:
   - Splits into ≤28-byte chunks
   - Sends as VTYPE_DATA (0xD1) packets with sequence numbers
   ↓
6. Node B: Receives and reassembles Base64 string
   ↓
7. Phone A: <VOICE_END>
   ↓
8. Node A → Node B: VTYPE_END (0xD2) packet
   ↓
9. Node B → Phone B: <VOICE_START> + Base64 audio + <VOICE_END>
```

## 📡 Address Configuration (Critical!)

### Address Array (Both Nodes)
```cpp
const byte address[][6] = {"1Node", "2Node"};
//                         ^^^^^^   ^^^^^^
//                         [0]      [1]
```

### Node A Setup
```
┌─────────────────────────┐
│      ESP32 Node A       │
│                         │
│  Writing Pipe:          │
│  → address[0] ("1Node") │───────┐
│                         │       │
│  Reading Pipe:          │       │
│  ← address[1] ("2Node") │◄──────┘
└─────────────────────────┘
```

### Node B Setup
```
┌─────────────────────────┐
│      ESP32 Node B       │
│                         │
│  Reading Pipe:          │
│  ← address[0] ("1Node") │◄──────┐
│                         │       │
│  Writing Pipe:          │       │
│  → address[1] ("2Node") │───────┘
└─────────────────────────┘
```

### The Connection
```
Node A writes to "1Node" ──────────────────────► Node B listens on "1Node" ✅
Node B writes to "2Node" ──────────────────────► Node A listens on "2Node" ✅
```

## 🔒 Data Integrity

### CRC8 Checksum
Every packet includes a CRC8 checksum calculated over:
```
[Packet Type (1 byte)][Sequence (2 bytes)][Payload (up to 28 bytes)]
```

**On Receive:**
1. Store received CRC8
2. Clear CRC8 byte in packet
3. Recalculate CRC8
4. Compare with received CRC8
5. If match: ✅ Process packet
6. If mismatch: ❌ Drop packet, log error (not sent to phone!)

## 🎤 Voice Channel Management

### Only One Voice Stream at a Time

```
Scenario: Phone A wants to send voice, but Phone B is already sending

1. Phone A: <VOICE_START>
   ↓
2. Node A: Checks channel
   - Is receiving voice? YES
   - Or just finished TX? YES (within 300ms)
   ↓
3. Node A → Phone A: <VOICE_DENY_BUSY>
   ↓
4. Phone A: Shows "Channel Busy" message to user
```

## 🔄 Bidirectional Capability

### Both Directions Simultaneously (Text Only)

```
Time:    0ms        100ms      200ms      300ms
         │          │          │          │
Phone A  │───Msg1───│          │          │
         │          │          │          │
Node A   │─RF─►Node B          │          │
         │          │          │          │
Node B   │          │─RF─►Node A          │
         │          │          │          │
Phone B  │          │───Msg2───│          │
```

**Note:** Voice messages block each other, but text messages can be sent in both directions.

## ⚙️ Configuration (Both Nodes Must Match)

| Setting | Value | Purpose |
|---------|-------|---------|
| **RF Channel** | 108 (2.508 GHz) | Must match for communication |
| **Data Rate** | 250KBPS | Robust, longer range |
| **Power Level** | PA_LOW | Conservative, stable |
| **Auto ACK** | Enabled | Automatic retries |
| **Dynamic Payloads** | Enabled | Variable packet sizes |
| **Retries** | 5 attempts, 15 intervals | Error recovery |

## 🐛 Common Issues

### ❌ Messages Not Arriving

**Possible Causes:**
1. **Wrong Pipe Addresses** - Most common!
   - Verify Node A writes to address[0], Node B listens on address[0]
   - Verify Node B writes to address[1], Node A listens on address[1]

2. **Different RF Channels**
   - Both must use channel 108
   - Check: `#define RF_CHANNEL 108` in both files

3. **Hardware Issues**
   - Check nRF24L01 wiring (CE, CSN, SPI)
   - Verify power supply (stable 3.3V)
   - Check antenna connections

4. **CRC Errors**
   - Monitor Serial Monitor for `[RF_ERR] CRC mismatch`
   - High error rate = hardware/wiring problem
   - These errors are filtered and won't appear in chat

### ✅ Quick Verification

**To test if nodes can communicate:**

1. Upload Node A code to first ESP32
2. Upload Node B code to second ESP32
3. Open Serial Monitor on both (115200 baud)
4. Send message from Phone A
5. Check Node A Serial Monitor: Should show "Text forwarded (JSON): ..."
6. Check Node B Serial Monitor: Should show "Text forwarded (JSON): ..."
7. Check Phone B: Should receive message

If Node A shows message but Node B doesn't → RF communication issue
If Node B shows message but Phone B doesn't → Bluetooth/Flutter app issue

