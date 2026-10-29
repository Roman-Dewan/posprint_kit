package com.example.posprint_kit

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Handles Android USB OTG thermal printer discovery, permission, and bulk-transfer writes.
 */
class UsbHandler(private val context: Context) {
    companion object {
        private const val ACTION_USB_PERMISSION = "com.example.posprint_kit.USB_PERMISSION"
    }

    private val scope = CoroutineScope(Dispatchers.Main)
    private val usbManager: UsbManager? by lazy {
        context.getSystemService(Context.USB_SERVICE) as? UsbManager
    }

    private var activeDevice: UsbDevice? = null
    private var activeConnection: UsbDeviceConnection? = null
    private var activeInterface: UsbInterface? = null
    private var activeEndpoint: UsbEndpoint? = null

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "usb.list" -> listDevices(result)
            "usb.requestPermission" -> requestPermission(call, result)
            "usb.connect" -> connect(call, result)
            "usb.write" -> write(call, result)
            "usb.disconnect" -> disconnect(result)
            else -> result.notImplemented()
        }
    }

    private fun listDevices(result: MethodChannel.Result) {
        val manager = usbManager
        if (manager == null) {
            result.error("USB_UNAVAILABLE", "USB Host service is not available on this device.", null)
            return
        }

        try {
            val deviceList = manager.deviceList
            val list = mutableListOf<Map<String, Any?>>()

            for ((_, device) in deviceList) {
                list.add(
                    mapOf(
                        "vendorId" to device.vendorId,
                        "productId" to device.productId,
                        "name" to (device.productName ?: "USB Thermal Printer"),
                        "deviceName" to device.deviceName,
                        "hasPermission" to manager.hasPermission(device)
                    )
                )
            }
            result.success(list)
        } catch (e: Exception) {
            result.error("LIST_FAILED", e.message, null)
        }
    }

    private fun requestPermission(call: MethodCall, result: MethodChannel.Result) {
        val manager = usbManager
        if (manager == null) {
            result.error("USB_UNAVAILABLE", "USB Host service unavailable.", null)
            return
        }

        val vendorId = call.argument<Int>("vendorId") ?: 0
        val productId = call.argument<Int>("productId") ?: 0

        val device = findDevice(vendorId, productId)
        if (device == null) {
            result.error(
                "DEVICE_NOT_FOUND",
                "No connected USB device matching vendor $vendorId, product $productId.",
                null
            )
            return
        }

        requestDevicePermission(device) { granted ->
            result.success(granted)
        }
    }

    private fun requestDevicePermission(device: UsbDevice, onResult: (Boolean) -> Unit) {
        val manager = usbManager ?: run {
            onResult(false)
            return
        }

        if (manager.hasPermission(device)) {
            onResult(true)
            return
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val intent = Intent(ACTION_USB_PERMISSION).apply {
            setPackage(context.packageName)
        }

        val permissionIntent = PendingIntent.getBroadcast(
            context,
            0,
            intent,
            flags
        )

        val filter = IntentFilter(ACTION_USB_PERMISSION)
        var receiverUnregistered = false

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(recvContext: Context?, recvIntent: Intent?) {
                if (recvIntent?.action == ACTION_USB_PERMISSION) {
                    synchronized(this@UsbHandler) {
                        if (!receiverUnregistered) {
                            receiverUnregistered = true
                            try {
                                context.unregisterReceiver(this)
                            } catch (_: Exception) {}
                        }
                    }

                    val extraDevice: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        recvIntent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        recvIntent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }

                    val granted = recvIntent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false) ||
                            (extraDevice != null && manager.hasPermission(extraDevice)) ||
                            manager.hasPermission(device)

                    onResult(granted)
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.registerReceiver(
                context,
                receiver,
                filter,
                ContextCompat.RECEIVER_EXPORTED
            )
        } else {
            context.registerReceiver(receiver, filter)
        }

        manager.requestPermission(device, permissionIntent)
    }

    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        val manager = usbManager
        if (manager == null) {
            result.error("USB_UNAVAILABLE", "USB Host unavailable.", null)
            return
        }

        val vendorId = call.argument<Int>("vendorId") ?: 0
        val productId = call.argument<Int>("productId") ?: 0

        val device = findDevice(vendorId, productId)
        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "USB printer device not found.", null)
            return
        }

        if (manager.hasPermission(device)) {
            openAndClaimDevice(device, manager, result)
        } else {
            // Prompt user for permission automatically before failing
            requestDevicePermission(device) { granted ->
                if (granted && manager.hasPermission(device)) {
                    openAndClaimDevice(device, manager, result)
                } else {
                    result.error(
                        "PERMISSION_DENIED",
                        "USB device permission not granted for this printer.",
                        null
                    )
                }
            }
        }
    }

    private fun openAndClaimDevice(
        device: UsbDevice,
        manager: UsbManager,
        result: MethodChannel.Result
    ) {
        scope.launch(Dispatchers.IO) {
            try {
                // Find printer or bulk-transfer OUT endpoint
                var targetInterface: UsbInterface? = null
                var targetEndpoint: UsbEndpoint? = null

                for (i in 0 until device.interfaceCount) {
                    val usbIf = device.getInterface(i)
                    for (e in 0 until usbIf.endpointCount) {
                        val ep = usbIf.getEndpoint(e)
                        if (ep.direction == UsbConstants.USB_DIR_OUT &&
                            ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK
                        ) {
                            targetInterface = usbIf
                            targetEndpoint = ep
                            break
                        }
                    }
                    if (targetEndpoint != null) break
                }

                if (targetInterface == null || targetEndpoint == null) {
                    withContext(Dispatchers.Main) {
                        result.error("NO_ENDPOINT", "No bulk-transfer print endpoint found on this USB device.", null)
                    }
                    return@launch
                }

                val conn = manager.openDevice(device)
                if (conn == null) {
                    withContext(Dispatchers.Main) {
                        result.error("CONNECTION_FAILED", "Could not open USB connection to printer.", null)
                    }
                    return@launch
                }

                conn.claimInterface(targetInterface, true)

                synchronized(this@UsbHandler) {
                    cleanup()
                    activeDevice = device
                    activeConnection = conn
                    activeInterface = targetInterface
                    activeEndpoint = targetEndpoint
                }

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("CONNECTION_FAILED", e.message, null)
                }
            }
        }
    }

    private fun write(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null || bytes.isEmpty()) {
            result.success(true)
            return
        }

        val conn = activeConnection
        val ep = activeEndpoint
        if (conn == null || ep == null) {
            result.error("CONNECTION_LOST", "Printer is not connected over USB.", null)
            return
        }

        scope.launch(Dispatchers.IO) {
            try {
                val transferred = conn.bulkTransfer(ep, bytes, bytes.size, 5000)
                if (transferred < 0) {
                    withContext(Dispatchers.Main) {
                        result.error("CONNECTION_LOST", "Failed to transfer bytes to USB printer ($transferred).", null)
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        result.success(true)
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("WRITE_FAILED", e.message, null)
                }
            }
        }
    }

    private fun disconnect(result: MethodChannel.Result) {
        scope.launch(Dispatchers.IO) {
            synchronized(this@UsbHandler) {
                cleanup()
            }
            withContext(Dispatchers.Main) {
                result.success(null)
            }
        }
    }

    private fun findDevice(vendorId: Int, productId: Int): UsbDevice? {
        val manager = usbManager ?: return null
        val devices = manager.deviceList.values
        if (devices.isEmpty()) return null

        if (vendorId > 0 && productId > 0) {
            val match = devices.firstOrNull { it.vendorId == vendorId && it.productId == productId }
            if (match != null) return match
        }

        // If only 1 USB device is connected, automatically use it
        if (devices.size == 1) {
            return devices.first()
        }

        // Otherwise find device with printer class (7) or bulk OUT endpoint
        for (dev in devices) {
            for (i in 0 until dev.interfaceCount) {
                val iface = dev.getInterface(i)
                if (iface.interfaceClass == 7) return dev
                for (e in 0 until iface.endpointCount) {
                    val ep = iface.getEndpoint(e)
                    if (ep.direction == UsbConstants.USB_DIR_OUT && ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                        return dev
                    }
                }
            }
        }

        return devices.firstOrNull()
    }

    private fun cleanup() {
        try {
            if (activeConnection != null && activeInterface != null) {
                activeConnection?.releaseInterface(activeInterface)
            }
            activeConnection?.close()
        } catch (_: Exception) {}
        activeDevice = null
        activeConnection = null
        activeInterface = null
        activeEndpoint = null
    }
}
