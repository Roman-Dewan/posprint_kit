package com.example.posprint_kit

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** PosprintKitPlugin */
class PosprintKitPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel: MethodChannel
    private var bluetoothHandler: BluetoothHandler? = null
    private var usbHandler: UsbHandler? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val context = flutterPluginBinding.applicationContext
        bluetoothHandler = BluetoothHandler(context)
        usbHandler = UsbHandler(context)

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "posprint_kit")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        // OLD:
        // if (call.method == "getPlatformVersion") {
        //     result.success("Android ${android.os.Build.VERSION.RELEASE}")
        // } else {
        //     result.notImplemented()
        // }
        when {
            call.method == "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            call.method.startsWith("bt.") -> {
                bluetoothHandler?.handleMethodCall(call, result) ?: result.error("BT_UNAVAILABLE", "Bluetooth handler not initialized", null)
            }
            call.method.startsWith("usb.") -> {
                usbHandler?.handleMethodCall(call, result) ?: result.error("USB_UNAVAILABLE", "USB handler not initialized", null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        bluetoothHandler = null
        usbHandler = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        bluetoothHandler?.setActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        bluetoothHandler?.setActivity(null)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        bluetoothHandler?.setActivity(binding.activity)
    }

    override fun onDetachedFromActivity() {
        bluetoothHandler?.setActivity(null)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        return bluetoothHandler?.onRequestPermissionsResult(requestCode, permissions, grantResults) ?: false
    }
}
