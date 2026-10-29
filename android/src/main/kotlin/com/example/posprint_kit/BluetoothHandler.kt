package com.example.posprint_kit

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException
import java.util.UUID

/**
 * Handles Bluetooth Classic SPP connections and writing for ESC/POS thermal printers.
 */
class BluetoothHandler(private val context: Context) {
    companion object {
        // Standard Serial Port Profile (SPP) UUID
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        private const val REQUEST_CODE_BT_PERM: Int = 9871
    }

    private val scope = CoroutineScope(Dispatchers.Main)
    private var activeSocket: BluetoothSocket? = null
    private var activity: Activity? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        BluetoothAdapter.getDefaultAdapter()
    }

    fun setActivity(act: Activity?) {
        activity = act
    }

    fun hasBluetoothPermissions(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val connectGranted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
            return connectGranted
        }
        return true
    }

    fun requestPermissions(result: MethodChannel.Result) {
        if (hasBluetoothPermissions()) {
            result.success(true)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val currentActivity = activity
            if (currentActivity == null) {
                result.error(
                    "PERMISSION_DENIED",
                    "Cannot prompt for Bluetooth permissions without an attached Activity. Please enable BLUETOOTH_CONNECT in Android Settings.",
                    null
                )
                return
            }

            pendingPermissionResult = result
            val permissions = arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN
            )
            ActivityCompat.requestPermissions(currentActivity, permissions, REQUEST_CODE_BT_PERM)
        } else {
            result.success(true)
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == REQUEST_CODE_BT_PERM) {
            val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.let { res ->
                if (granted) {
                    res.success(true)
                } else {
                    res.error(
                        "PERMISSION_DENIED",
                        "Bluetooth permissions (BLUETOOTH_CONNECT) were denied by the user.",
                        null
                    )
                }
                pendingPermissionResult = null
            }
            return true
        }
        return false
    }

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "bt.listPaired" -> listPairedDevices(result)
            "bt.requestPermission" -> requestPermissions(result)
            "bt.connect" -> connect(call, result)
            "bt.write" -> write(call, result)
            "bt.disconnect" -> disconnect(result)
            else -> result.notImplemented()
        }
    }

    @SuppressLint("MissingPermission")
    private fun listPairedDevices(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth is not available on this device.", null)
            return
        }

        if (!adapter.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is turned off. Please enable Bluetooth in settings.", null)
            return
        }

        if (!hasBluetoothPermissions()) {
            result.error(
                "PERMISSION_DENIED",
                "Need android.permission.BLUETOOTH_CONNECT permission for getBondedDevices.",
                null
            )
            return
        }

        try {
            val paired = adapter.bondedDevices ?: emptySet()
            val list = paired.map { device ->
                mapOf(
                    "name" to (device.name ?: "Unknown Printer"),
                    "address" to device.address
                )
            }
            result.success(list)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Bluetooth permissions missing: ${e.message}", null)
        } catch (e: Exception) {
            result.error("LIST_FAILED", e.message, null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("address")
        if (address.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Bluetooth device address cannot be empty.", null)
            return
        }

        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is disabled or unavailable.", null)
            return
        }

        if (!hasBluetoothPermissions()) {
            result.error(
                "PERMISSION_DENIED",
                "Need android.permission.BLUETOOTH_CONNECT permission to connect to Bluetooth devices.",
                null
            )
            return
        }

        scope.launch(Dispatchers.IO) {
            try {
                // Cancel ongoing discovery before connecting to avoid link degradation
                try {
                    adapter.cancelDiscovery()
                } catch (_: Exception) {}

                val device: BluetoothDevice = adapter.getRemoteDevice(address)
                val socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()

                synchronized(this@BluetoothHandler) {
                    try { activeSocket?.close() } catch (_: Exception) {}
                    activeSocket = socket
                }

                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: SecurityException) {
                withContext(Dispatchers.Main) {
                    result.error("PERMISSION_DENIED", "Missing Bluetooth connect permission: ${e.message}", null)
                }
            } catch (e: IOException) {
                withContext(Dispatchers.Main) {
                    result.error("CONNECTION_FAILED", "Failed to connect to Bluetooth device $address: ${e.message}", null)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("UNKNOWN", e.message, null)
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

        val socket = activeSocket
        if (socket == null || !socket.isConnected) {
            result.error("CONNECTION_LOST", "Printer is not connected over Bluetooth.", null)
            return
        }

        scope.launch(Dispatchers.IO) {
            try {
                val out = socket.outputStream
                out.write(bytes)
                out.flush()
                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: IOException) {
                synchronized(this@BluetoothHandler) {
                    try { socket.close() } catch (_: Exception) {}
                    activeSocket = null
                }
                withContext(Dispatchers.Main) {
                    result.error("CONNECTION_LOST", "Lost connection to Bluetooth printer: ${e.message}", null)
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
            synchronized(this@BluetoothHandler) {
                try {
                    activeSocket?.close()
                } catch (_: Exception) {}
                activeSocket = null
            }
            withContext(Dispatchers.Main) {
                result.success(null)
            }
        }
    }
}
