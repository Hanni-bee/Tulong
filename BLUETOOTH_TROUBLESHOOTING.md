# Bluetooth Connection Troubleshooting Guide

## Problem: "Kapag nakaconnect na sa B, nagcoconnect. Pero kapag magcoconnect sa A, nagdidisconnect"

### Possible Causes:

1. **Same Code Uploaded to Both ESP32s** ❌
   - Check: Did you upload `esp32_node_A_nrf24.ino` to Node A ESP32?
   - Check: Did you upload `esp32_node_B_nrf24.ino` to Node B ESP32?
   - **Solution**: Make sure each ESP32 has the correct code!

2. **Phone Bluetooth Cache** 🔄
   - The phone might have cached the old Bluetooth connection
   - **Solution**: 
     - Go to Phone Settings → Bluetooth
     - Find "ESP32_Node_A" or "ESP32_Node_B"
     - Tap the gear icon → "Forget" or "Unpair"
     - Try connecting again

3. **ESP32 Bluetooth Names Conflict** 📱
   - If both ESP32s show the same name, you're connecting to the wrong one
   - **Check Serial Monitor**:
     - Node A should show: `[OK] BT ready: ESP32_Node_A`
     - Node B should show: `[OK] BT ready: ESP32_Node_B`

4. **Connection Order Issue** ⚠️
   - Try this order:
     1. Upload Node A code to first ESP32
     2. Upload Node B code to second ESP32
     3. Wait 5 seconds after upload
     4. Connect Phone 1 to "ESP32_Node_A"
     5. Connect Phone 2 to "ESP32_Node_B"

## Step-by-Step Fix:

### Step 1: Verify Correct Code Upload
```
Node A ESP32 → Upload esp32_node_A_nrf24.ino
Node B ESP32 → Upload esp32_node_B_nrf24.ino
```

### Step 2: Check Serial Monitor
Open Serial Monitor (115200 baud) for BOTH ESP32s:

**Node A should show:**
```
=== ESP32 NODE A ===
Device: ESP32_Node_A
Node ID: NodeA_XXXX
[OK] BT ready: ESP32_Node_A
```

**Node B should show:**
```
=== ESP32 NODE B ===
Device: ESP32_Node_B
Node ID: NodeB_XXXX
[OK] BT ready: ESP32_Node_B
```

### Step 3: Clear Phone Bluetooth Cache

**On Phone 1:**
1. Settings → Bluetooth
2. Find "ESP32_Node_A" → Forget/Unpair
3. Find "ESP32_Node_B" → Forget/Unpair (if exists)
4. Restart Bluetooth

**On Phone 2:**
1. Settings → Bluetooth
2. Find "ESP32_Node_A" → Forget/Unpair (if exists)
3. Find "ESP32_Node_B" → Forget/Unpair
4. Restart Bluetooth

### Step 4: Connect in Order

1. **First**, connect Phone 1 to Node A:
   - Open Bluetooth on Phone 1
   - Look for "ESP32_Node_A"
   - Connect
   - Check Serial Monitor Node A: Should show `[BT] ✓ CLIENT CONNECTED`

2. **Then**, connect Phone 2 to Node B:
   - Open Bluetooth on Phone 2
   - Look for "ESP32_Node_B"
   - Connect
   - Check Serial Monitor Node B: Should show `[BT] ✓ CLIENT CONNECTED`

### Step 5: Verify Connection

**Node A Serial Monitor:**
```
========================================
[BT] ✓ CLIENT CONNECTED
[BT] Device: ESP32_Node_A
========================================
```

**Node B Serial Monitor:**
```
========================================
[BT] ✓ CLIENT CONNECTED
[BT] Device: ESP32_Node_B
========================================
```

## Common Mistakes:

1. ❌ Uploaded Node B code to Node A ESP32
2. ❌ Phone trying to connect to wrong device
3. ❌ Old Bluetooth pairing still cached
4. ❌ Both ESP32s powered on but wrong code uploaded
5. ❌ Trying to connect both phones to the same ESP32

## Test Message Flow:

1. Send message from Phone 1 (connected to Node A)
2. Check Node A Serial Monitor: Should show message received
3. Check Node B Serial Monitor: Should show NRF24 chunk reception
4. Check Phone 2: Should display the message

## Still Not Working?

Check these:
- ✅ Both ESP32s have power?
- ✅ Serial Monitor shows correct device names?
- ✅ Phones can see both "ESP32_Node_A" and "ESP32_Node_B"?
- ✅ NRF24L01 modules properly connected?
- ✅ No other Bluetooth devices interfering?

