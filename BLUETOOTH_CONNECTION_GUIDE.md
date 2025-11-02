# Bluetooth Connection Guide - ESP32

## ❗ Important Limitation

**ESP32 BluetoothSerial (Classic Bluetooth) supports ONLY ONE connection at a time per ESP32.**

## Current Setup

### ✅ Correct Setup (Recommended):
```
Phone 1 → ESP32 Node A → NRF24L01 → ESP32 Node B → Phone 2
```

**How it works:**
- **Phone 1** connects to **ESP32 Node A**
- **Phone 2** connects to **ESP32 Node B**
- Messages flow: Phone 1 → Node A → Node B → Phone 2

### ❌ Won't Work:
```
Phone 1 ─┐
         ├→ ESP32 Node A (only one can connect)
Phone 2 ─┘
```

**Why?** 
- `BluetoothSerial` can only handle ONE client at a time
- When Phone 1 is connected, Phone 2 cannot connect to the same ESP32
- When Phone 2 tries to connect, it will fail or disconnect Phone 1

## Solutions

### Option 1: Use Two ESP32s (Current Setup) ✅
- **Node A**: Connect Phone 1
- **Node B**: Connect Phone 2
- Messages relay through NRF24L01

### Option 2: Disconnect Before Connecting
If you only have one ESP32:
1. Phone 1 connects first
2. Send messages
3. **Disconnect Phone 1**
4. **Then** Phone 2 can connect
5. Send/receive messages

### Option 3: Automatic Connection Switching (Future)
Could modify code to:
- Accept new connection
- Disconnect old connection automatically
- But you'll lose connection to first phone

## Troubleshooting

### Problem: "Can't connect Phone 2 when Phone 1 is connected"

**Solution:** This is normal behavior. ESP32 Classic Bluetooth supports only one connection.

**Options:**
1. **Use two ESP32s** (recommended) - One phone per ESP32
2. **Disconnect Phone 1 first**, then connect Phone 2
3. **Check if phones are paired** - Go to phone Bluetooth settings and forget ESP32 device

### Problem: "Connection drops when trying to connect another phone"

**Solution:** ESP32 is switching to the new connection. The old connection will be disconnected.

## Best Practice

**For two-way communication with two phones:**
- Use **two ESP32 devices**
- **Node A** → Phone 1
- **Node B** → Phone 2
- Messages automatically relay via NRF24L01

## Testing

1. **Upload Node A code** to first ESP32
2. **Upload Node B code** to second ESP32  
3. **Connect Phone 1** to "ESP32_Node_A"
4. **Connect Phone 2** to "ESP32_Node_B"
5. **Send message from Phone 1** → Should appear on Phone 2
6. **Send message from Phone 2** → Should appear on Phone 1

## Serial Monitor Output

When connected:
```
[BT] Client connected
[INFO] Note: Only ONE phone can connect at a time per ESP32
[INFO] To connect another phone, disconnect current one first
```

When disconnected:
```
[BT] Client disconnected
[BT] Ready for new connection
```

