# How Node A and Node B Work Together

## 📡 Overall Architecture

```
Phone A  <—Bluetooth SPP—>  ESP32 Node A  <—nRF24L01 (2.4GHz RF)—>  ESP32 Node B  <—Bluetooth SPP—>  Phone B
```

## 🔄 Communication Flow

### **Two-Way Communication Setup**

Both nodes are **bidirectional** - they can send and receive messages simultaneously.

#### **Pipe Address Configuration:**

```cpp
// Both nodes use the same address array:
const byte address[][6] = {"1Node", "2Node"};
```

**Node A Configuration:**
```cpp
radio.openWritingPipe(address[0]);    // Sends to "1Node"
radio.openReadingPipe(1, address[1]); // Listens on "2Node"
```
- **Writes to**: `address[0]` ("1Node") - Where it sends messages
- **Reads on**: `address[1]` ("2Node") - Where it receives messages

**Node B Configuration:**
```cpp
radio.openWritingPipe(address[1]);    // Sends to "2Node"
radio.openReadingPipe(1, address[0]); // Listens on "1Node"
```
- **Writes to**: `address[1]` ("2Node") - Where it sends messages
- **Reads on**: `address[0]` ("1Node") - Where it receives messages

**Why This Works:**
- Node A sends to "1Node" → Node B is listening on "1Node" ✅
- Node B sends to "2Node" → Node A is listening on "2Node" ✅
- This creates a **perfect bidirectional communication pattern**

## 📨 Message Flow Examples

### **Example 1: Regular Text Message**

**Phone A → Phone B:**
```
1. Phone A sends: {"type":"group", "message":"Hello!", "is_emergency":false}
   ↓ (Bluetooth SPP)
2. ESP32 Node A receives via SerialBT
   ↓ (Parses JSON, extracts message)
3. ESP32 Node A sends via nRF24:
   - Type: VTYPE_TEXT (0xA0)
   - Chunks message into 28-byte packets with sequence numbers
   - Each packet has CRC8 checksum
   ↓ (2.4GHz RF - Channel 108)
4. ESP32 Node B receives packets
   - Verifies CRC8
   - Reassembles message from chunks
   - Wraps back into JSON format
   ↓ (Bluetooth SPP)
5. Phone B receives: {"type":"group", "message":"Hello!", "is_emergency":false}
```

### **Example 2: Emergency/SOS Message**

**Phone A → Phone B (Emergency):**
```
1. Phone A sends: {"type":"group", "message":"HELP!", "is_emergency":true}
   ↓
2. ESP32 Node A receives via SerialBT
   ↓ (Detects is_emergency flag)
3. ESP32 Node A sends via nRF24:
   - Type: VTYPE_SOS (0xA1) ← Different packet type!
   - Same chunking process
   ↓
4. ESP32 Node B receives VTYPE_SOS packets
   - Reassembles message
   - Creates JSON with is_emergency:true
   ↓
5. Phone B receives emergency message with special handling
```

### **Example 3: Voice Message**

**Phone A → Phone B (Voice):**
```
1. Phone A sends: <VOICE_START>
   ↓
2. ESP32 Node A checks if channel is busy
   - If busy: Sends <VOICE_DENY_BUSY> back to Phone A
   - If free: Sends VTYPE_START (0xD0) packet via nRF24
   ↓
3. Phone A streams Base64-encoded audio:
   - Each line sent as Base64
   - ESP32 Node A splits each line into ≤28-byte chunks
   - Each chunk sent as VTYPE_DATA (0xD1) with sequence number
   ↓
4. ESP32 Node B receives packets:
   - Reassembles Base64 string
   - Detects end of stream (timeout or VTYPE_END)
   ↓
5. ESP32 Node B sends to Phone B:
   <VOICE_START>
   [reassembled Base64 audio]
   <VOICE_END>
```

## 🔧 Key Mechanisms

### **1. Packet Chunking (Messages > 28 bytes)**

Both nodes automatically chunk long messages:

```
Original: "This is a very long message that exceeds 28 characters..."
↓
Packet 0: "This is a very long message t" (28 bytes, seq=0)
Packet 1: "hat exceeds 28 characters..." (26 bytes, seq=1, <28 = last)
```

**Reassembly on receiving node:**
- Tracks expected sequence numbers
- Reassembles in order
- When packet length < 28, knows it's the last packet

### **2. CRC8 Error Detection**

Every packet includes a CRC8 checksum:
- **Sender**: Calculates CRC8 over [type|sequence|payload]
- **Receiver**: Recalculates and compares
- **On mismatch**: Packet is dropped, error logged (but NOT sent to phone as message)

### **3. Channel Busy Detection**

Both nodes check if channel is busy before transmitting:
- Detects ongoing RF activity
- Checks if receiving a voice stream
- Enforces cooldown period after transmission

### **4. Debug Log Filtering**

**Important:** ESP32 debug logs (like `[RF_ERR] CRC mismatch`) are:
- Logged to Serial Monitor
- Forwarded via Bluetooth (for debugging)
- **BUT**: Filtered out by Flutter app (not shown as chat messages)

## 🔄 Bidirectional Communication

### **Both Nodes Can Send Simultaneously (But Not Voice)**

**Text Messages:**
- Node A can send text while Node B is sending text
- Messages are queued and sent sequentially
- Each message is chunked and reassembled independently

**Voice Messages:**
- Only ONE node can transmit voice at a time
- The other node will receive `<VOICE_DENY_BUSY>` if channel is occupied
- Voice has priority and blocks other voice transmissions

## 📊 RF Configuration (Both Nodes Identical)

- **Channel**: 108 (2.508 GHz)
- **Data Rate**: 250KBPS (robust, longer range)
- **Power Level**: PA_LOW (conservative, can be increased if needed)
- **Auto ACK**: Enabled (automatic retries)
- **Dynamic Payloads**: Enabled (variable packet sizes)

## 🔍 Troubleshooting Communication

### **If Messages Don't Arrive:**

1. **Check Pipe Addresses:**
   - Node A must write to `address[0]` (where Node B listens)
   - Node B must write to `address[1]` (where Node A listens)
   - If swapped, they'll never receive each other's messages

2. **Check RF Channel:**
   - Both must use channel 108
   - Different channels = no communication

3. **Check Power and Antennas:**
   - nRF24L01 needs stable 3.3V power
   - Antennas must be properly connected
   - Distance should be within RF range

4. **Check CRC Errors:**
   - Monitor Serial Monitor for `[RF_ERR] CRC mismatch`
   - High error rate indicates hardware/wiring issues
   - These errors are filtered and won't appear in chat

5. **Verify JSON Format:**
   - Both nodes should send messages as JSON
   - Flutter app expects: `{"type":"group", "message":"...", "is_emergency":false}`
   - Plain text messages are wrapped automatically

## ✅ Summary

**The two nodes work as a transparent bridge:**

1. **Receive** messages from their connected phone via Bluetooth
2. **Transmit** messages to the other node via nRF24L01 RF
3. **Receive** messages from the other node via nRF24L01 RF
4. **Forward** messages to their connected phone via Bluetooth

**All of this happens automatically** - you just send a message from Phone A, and it appears on Phone B, and vice versa!

