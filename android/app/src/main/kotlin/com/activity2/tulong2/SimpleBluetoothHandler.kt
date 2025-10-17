package com.activity2.tulong2

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
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

class SimpleBluetoothHandler(private val flutterEngine: FlutterEngine) : MethodChannel.MethodCallHandler {
    
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
    
    init {
        channel.setMethodCallHandler(this)
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connectToESP32" -> connectToESP32(result)
            "disconnect" -> disconnect(result)
            "sendMessage" -> {
                val message = call.argument<String>("message")
                if (message != null) {
                    sendMessage(message, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Message is null", null)
                }
            }
            else -> result.notImplemented()
        }
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
    
    private fun sendMessage(message: String, result: MethodChannel.Result) {
        if (!isConnected || outputStream == null) {
            result.error("NOT_CONNECTED", "Not connected to ESP32", null)
            return
        }
        
        Thread {
            try {
                outputStream?.write((message + "\n").toByteArray())
                outputStream?.flush()
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
        disconnect(null)
        channel.setMethodCallHandler(null)
    }
}

