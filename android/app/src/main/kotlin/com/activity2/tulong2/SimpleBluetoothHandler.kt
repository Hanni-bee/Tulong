package com.activity2.tulong2

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.*

class SimpleBluetoothHandler(
    private val context: Context,
    flutterEngine: FlutterEngine
) : MethodChannel.MethodCallHandler {
    
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "simple_bluetooth")
    private val mainHandler = Handler(Looper.getMainLooper())
    
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null
    private var inputStream: InputStream? = null
    private var readThread: Thread? = null
    private var isConnected = false
    
    companion object {
        private const val ESP32_DEVICE_PREFIX = "ESP32_Node"  // Will match ESP32_Node_A, ESP32_Node_B, etc.
        private val ESP32_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB") // Standard SPP UUID
    }

    private val bluetoothStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action
            if (action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                when (state) {
                    BluetoothAdapter.STATE_OFF -> {
                        mainHandler.post {
                            updateStatus("Bluetooth turned off")
                            if (isConnected) {
                                disconnect(null)
                            }
                            val args = mapOf("enabled" to false)
                            channel.invokeMethod("onAdapterStateChanged", args)
                        }
                    }
                    BluetoothAdapter.STATE_TURNING_OFF -> {
                         mainHandler.post {
                            updateStatus("Bluetooth turning off...")
                        }
                    }
                    BluetoothAdapter.STATE_ON -> {
                        mainHandler.post {
                            updateStatus("Bluetooth turned on")
                            val args = mapOf("enabled" to true)
                            channel.invokeMethod("onAdapterStateChanged", args)
                        }
                    }
                }
            }
        }
    }
    
    init {
        channel.setMethodCallHandler(this)
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        
        // Register receiver for Bluetooth state changes using the provided Context
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        context.registerReceiver(bluetoothStateReceiver, filter)
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scanDevices" -> scanForDevices(result)
            "pairDevice" -> {
                val name = call.argument<String>("name")
                val address = call.argument<String>("address")
                if (name != null && address != null) {
                    pairDevice(name, address, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Name or address is null", null)
                }
            }
            "connectToESP32" -> connectToESP32(result)
            "disconnect" -> disconnect(result)
            "sendMessage" -> {
                // Accept the entire argument map and convert to JSON
                val messageData = call.arguments as? Map<*, *>
                if (messageData != null) {
                    sendMessage(messageData, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Message data is null", null)
                }
            }
            else -> result.notImplemented()
        }
    }
    
    private fun scanForDevices(result: MethodChannel.Result) {
        Thread {
            try {
                if (bluetoothAdapter == null) {
                    mainHandler.post {
                        result.error("NO_BLUETOOTH", "Bluetooth not available", null)
                    }
                    return@Thread
                }
                
                if (!bluetoothAdapter!!.isEnabled) {
                    mainHandler.post {
                        result.error("BLUETOOTH_DISABLED", "Please enable Bluetooth", null)
                    }
                    return@Thread
                }
                
                // Get bonded devices
                val devices = mutableListOf<Map<String, String>>()
                
                try {
                    val bondedDevices = bluetoothAdapter!!.bondedDevices
                    for (device in bondedDevices) {
                        if (device.name != null && device.name.startsWith("ESP32_Node")) {
                            devices.add(mapOf(
                                "name" to device.name,
                                "address" to device.address,
                                "bonded" to "true"
                            ))
                        }
                    }
                } catch (e: SecurityException) {
                    mainHandler.post {
                        result.error("PERMISSION_DENIED", "Bluetooth permission required", null)
                    }
                    return@Thread
                }
                
                mainHandler.post {
                    result.success(devices)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("SCAN_ERROR", "Error scanning: ${e.message}", null)
                }
            }
        }.start()
    }
    
    private fun pairDevice(name: String, address: String, result: MethodChannel.Result) {
        Thread {
            try {
                if (bluetoothAdapter == null) {
                    mainHandler.post {
                        result.error("NO_BLUETOOTH", "Bluetooth not available", null)
                    }
                    return@Thread
                }
                
                val device = bluetoothAdapter!!.getRemoteDevice(address)
                
                try {
                    // Check if already bonded
                    if (device.bondState == BluetoothDevice.BOND_BONDED) {
                        mainHandler.post {
                            result.success(true)
                        }
                        return@Thread
                    }
                    
                    // Attempt to pair
                    val createBondMethod = device.javaClass.getMethod("createBond")
                    val bondResult = createBondMethod.invoke(device) as Boolean
                    
                    mainHandler.post {
                        result.success(bondResult)
                    }
                    
                } catch (e: SecurityException) {
                    mainHandler.post {
                        result.error("PERMISSION_DENIED", "Bluetooth permission required", null)
                    }
                } catch (e: Exception) {
                    mainHandler.post {
                        result.error("PAIR_ERROR", "Pairing failed: ${e.message}", null)
                    }
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("DEVICE_ERROR", "Device error: ${e.message}", null)
                }
            }
        }.start()
    }
    
    private fun connectToESP32(result: MethodChannel.Result) {
        Thread {
            try {
                // Check if Bluetooth is available and enabled
                if (bluetoothAdapter == null) {
                    mainHandler.post {
                        result.error("NO_BLUETOOTH", "Bluetooth not available on this device", null)
                    }
                    return@Thread
                }
                
                if (!bluetoothAdapter!!.isEnabled) {
                    mainHandler.post {
                        result.error("BLUETOOTH_DISABLED", "Please enable Bluetooth", null)
                    }
                    return@Thread
                }
                
                // Update status
                updateStatus("Searching for ESP32...")
                
                // Find ESP32 device
                var esp32Device: BluetoothDevice? = null
                
                try {
                    // Check bonded devices first - find any ESP32_Node device
                    val bondedDevices = bluetoothAdapter!!.bondedDevices
                    for (device in bondedDevices) {
                        if (device.name != null && device.name.startsWith(ESP32_DEVICE_PREFIX)) {
                            esp32Device = device
                            updateStatus("Found: ${device.name}")
                            break
                        }
                    }
                } catch (e: SecurityException) {
                    mainHandler.post {
                        result.error("PERMISSION_DENIED", "Bluetooth permission required", null)
                    }
                    return@Thread
                }
                
                if (esp32Device == null) {
                    mainHandler.post {
                        result.error("DEVICE_NOT_FOUND", 
                            "No ESP32 device found. Please pair with 'ESP32_Node_A' or 'ESP32_Node_B' first.", null)
                    }
                    return@Thread
                }
                
                updateStatus("Found ESP32, connecting...")
                
                // Close existing connection if any
                disconnect(null)
                
                // Create socket
                bluetoothSocket = esp32Device.createRfcommSocketToServiceRecord(ESP32_UUID)
                
                // Cancel discovery to save power
                try {
                    bluetoothAdapter!!.cancelDiscovery()
                } catch (e: SecurityException) {
                    // Ignore
                }
                
                // Connect
                try {
                    bluetoothSocket?.connect()
                } catch (e: IOException) {
                    mainHandler.post {
                        result.error("CONNECTION_FAILED", 
                            "Failed to connect: ${e.message}. Try pairing manually first.", null)
                    }
                    return@Thread
                }
                
                // Get streams
                inputStream = bluetoothSocket?.inputStream
                outputStream = bluetoothSocket?.outputStream
                isConnected = true
                
                updateStatus("Connected")
                updateConnectionState(true)
                
                // Start reading thread
                startReadThread()
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("UNKNOWN_ERROR", "Connection error: ${e.message}", null)
                }
            }
        }.start()
    }
    
    private fun disconnect(result: MethodChannel.Result?) {
        try {
            isConnected = false
            
            // Stop read thread
            readThread?.interrupt()
            readThread = null
            
            // Close streams
            inputStream?.close()
            outputStream?.close()
            
            // Close socket
            bluetoothSocket?.close()
            
            inputStream = null
            outputStream = null
            bluetoothSocket = null
            
            updateStatus("Disconnected")
            updateConnectionState(false)
            
            result?.success(true)
        } catch (e: Exception) {
            result?.error("DISCONNECT_ERROR", "Error disconnecting: ${e.message}", null)
        }
    }
    
    private fun sendMessage(messageData: Map<*, *>, result: MethodChannel.Result) {
        if (!isConnected || outputStream == null) {
            result.error("NOT_CONNECTED", "Not connected to ESP32", null)
            return
        }
        
        Thread {
            try {
                // Convert Map to JSON string
                val jsonString = mapToJson(messageData)
                
                // Send with newline terminator
                outputStream?.write((jsonString + "\n").toByteArray())
                outputStream?.flush()
                
                // Log for debugging
                updateStatus("TX: $jsonString")
                
                mainHandler.post {
                    result.success(true)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("SEND_ERROR", "Error sending message: ${e.message}", null)
                }
            }
        }.start()
    }
    
    // Helper function to convert Map to JSON string
    private fun mapToJson(map: Map<*, *>): String {
        val json = StringBuilder("{")
        var first = true
        for ((key, value) in map) {
            if (!first) json.append(",")
            first = false
            json.append("\"${key}\":")
            when (value) {
                is String -> json.append("\"${value}\"")
                is Number -> json.append(value)
                is Boolean -> json.append(value)
                is Map<*, *> -> json.append(mapToJson(value))
                else -> json.append("\"${value}\"")
            }
        }
        json.append("}")
        return json.toString()
    }
    
    private fun startReadThread() {
        readThread = Thread {
            val buffer = ByteArray(1024)
            var stringBuffer = StringBuilder()
            
            while (isConnected && !Thread.currentThread().isInterrupted) {
                try {
                    if (inputStream == null) {
                        // Stream is null, break the loop
                        break
                    }
                    
                    val bytes = inputStream?.read(buffer)
                    
                    // Check for EOF or error
                    if (bytes == null || bytes == -1) {
                        // Connection closed by remote device
                        if (isConnected) {
                            mainHandler.post {
                                updateConnectionState(false)
                                updateStatus("Device disconnected")
                                notifyError("ESP32 closed the connection")
                            }
                            isConnected = false
                        }
                        break
                    }
                    
                    if (bytes > 0) {
                        val data = String(buffer, 0, bytes)
                        stringBuffer.append(data)
                        
                        // Check for complete messages (ending with newline)
                        var newlineIndex = stringBuffer.indexOf("\n")
                        while (newlineIndex != -1) {
                            val message = stringBuffer.substring(0, newlineIndex).trim()
                            if (message.isNotEmpty()) {
                                handleReceivedMessage(message)
                            }
                            stringBuffer.delete(0, newlineIndex + 1)
                            newlineIndex = stringBuffer.indexOf("\n")
                        }
                        
                        // Prevent buffer from growing too large
                        if (stringBuffer.length > 2048) {
                            stringBuffer.clear()
                        }
                    }
                } catch (e: IOException) {
                    if (isConnected) {
                        mainHandler.post {
                            updateConnectionState(false)
                            updateStatus("Connection error")
                            notifyError("Read error: ${e.message}")
                        }
                        isConnected = false
                    }
                    break
                } catch (e: Exception) {
                    if (isConnected) {
                        mainHandler.post {
                            notifyError("Unexpected error: ${e.message}")
                        }
                    }
                    break
                }
            }
            
            // Clean up when thread exits
            try {
                inputStream?.close()
                outputStream?.close()
                bluetoothSocket?.close()
            } catch (e: Exception) {
                // Ignore cleanup errors
            }
        }
        readThread?.start()
    }
    
    private fun handleReceivedMessage(message: String) {
        mainHandler.post {
            val args = mapOf("message" to message)
            channel.invokeMethod("onMessageReceived", args)
        }
    }
    
    private fun updateStatus(status: String) {
        mainHandler.post {
            val args = mapOf("status" to status)
            channel.invokeMethod("onStatusChanged", args)
        }
    }
    
    private fun updateConnectionState(connected: Boolean) {
        mainHandler.post {
            val args = mapOf(
                "connected" to connected,
                "status" to if (connected) "Connected" else "Disconnected"
            )
            channel.invokeMethod("onBluetoothStateChanged", args)
        }
    }
    
    private fun notifyError(error: String) {
        mainHandler.post {
            val args = mapOf("error" to error)
            channel.invokeMethod("onError", args)
        }
    }
    
    fun cleanup() {
        try {
            context.unregisterReceiver(bluetoothStateReceiver)
        } catch (e: Exception) {
            // Ignore if not registered
        }
        disconnect(null)
        channel.setMethodCallHandler(null)
    }
}
