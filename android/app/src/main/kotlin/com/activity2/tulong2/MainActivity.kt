package com.activity2.tulong2

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    private var bluetoothHandler: SimpleBluetoothHandler? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Bluetooth handler
        bluetoothHandler = SimpleBluetoothHandler(flutterEngine)
    }
    
    override fun onDestroy() {
        bluetoothHandler?.cleanup()
        bluetoothHandler = null
        super.onDestroy()
    }
}
