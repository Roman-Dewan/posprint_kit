package com.example.posprint_kit

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.sunmi.peripheral.printer.InnerPrinterCallback
import com.sunmi.peripheral.printer.InnerPrinterException
import com.sunmi.peripheral.printer.InnerPrinterManager
import com.sunmi.peripheral.printer.SunmiPrinterService
import com.sunmi.printerx.PrinterSdk
import com.sunmi.printerx.PrinterSdk.Printer
import com.sunmi.printerx.PrinterSdk.PrinterListen
import com.sunmi.printerx.SdkException
import com.sunmi.printerx.api.CashDrawerApi
import com.sunmi.printerx.api.CommandApi
import com.sunmi.printerx.api.LineApi
import com.sunmi.printerx.api.QueryApi
import com.sunmi.printerx.enums.Align
import com.sunmi.printerx.enums.DividingLine
import com.sunmi.printerx.enums.ErrorLevel
import com.sunmi.printerx.enums.HumanReadable
import com.sunmi.printerx.enums.PrinterInfo
import com.sunmi.printerx.enums.Symbology
import com.sunmi.printerx.style.BarcodeStyle
import com.sunmi.printerx.style.BaseStyle
import com.sunmi.printerx.style.QrStyle
import com.sunmi.printerx.style.TextStyle
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Handles communication with the built-in thermal receipt printer on Sunmi POS terminals
 * (e.g. Sunmi D3, V2, V2s, T2) using Sunmi's PrinterX SDK and InnerPrinter service.
 */
class SunmiHandler(private val context: Context) {
    private var activePrinter: Printer? = null
    private var commandApi: CommandApi? = null
    private var queryApi: QueryApi? = null
    private var cashDrawerApi: CashDrawerApi? = null
    private var lineApi: LineApi? = null
    private var sunmiPrinterService: SunmiPrinterService? = null

    private val scope = CoroutineScope(Dispatchers.Main)
    private val mainHandler = Handler(Looper.getMainLooper())

    private val innerPrinterCallback = object : InnerPrinterCallback() {
        override fun onConnected(service: SunmiPrinterService?) {
            sunmiPrinterService = service
        }

        override fun onDisconnected() {
            sunmiPrinterService = null
        }
    }

    init {
        bindInnerPrinterService()
    }

    private fun bindInnerPrinterService() {
        try {
            InnerPrinterManager.getInstance().bindService(context, innerPrinterCallback)
        } catch (_: Exception) {}
    }

    fun destroy() {
        try {
            InnerPrinterManager.getInstance().unBindService(context, innerPrinterCallback)
        } catch (_: Exception) {}
    }

    fun isSunmiDevice(): Boolean {
        val manufacturer = Build.MANUFACTURER.orEmpty()
        val brand = Build.BRAND.orEmpty()
        return manufacturer.equals("SUNMI", ignoreCase = true) || brand.equals("SUNMI", ignoreCase = true)
    }

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sunmi.isSupported" -> result.success(isSunmiDevice())
            "sunmi.connect" -> connect(result)
            "sunmi.write" -> write(call, result)
            "sunmi.printReceipt" -> printReceipt(call, result)
            "sunmi.disconnect" -> disconnect(result)
            "sunmi.getPaperWidth" -> getPaperWidth(result)
            "sunmi.getStatus" -> getStatus(result)
            "sunmi.openDrawer" -> openDrawer(result)
            else -> result.notImplemented()
        }
    }

    /**
     * Ensures the built-in printer service is bound and APIs are initialized.
     * Reuses active instances if already connected.
     */
    private fun ensurePrinterConnected(
        onSuccess: (Printer, CommandApi?) -> Unit,
        onError: (String, String) -> Unit
    ) {
        val currentPrinter = activePrinter
        val currentCmd = commandApi
        if (currentPrinter != null && currentCmd != null) {
            onSuccess(currentPrinter, currentCmd)
            return
        }

        val hasResponded = AtomicBoolean(false)
        val timeoutRunnable = Runnable {
            if (hasResponded.compareAndSet(false, true)) {
                onError("CONNECTION_TIMEOUT", "Timed out waiting for Sunmi Printer Service to respond.")
            }
        }
        mainHandler.postDelayed(timeoutRunnable, 5000)

        try {
            PrinterSdk.getInstance().getPrinter(context, object : PrinterListen {
                override fun onDefPrinter(printer: Printer?) {
                    mainHandler.removeCallbacks(timeoutRunnable)
                    if (printer != null) {
                        synchronized(this@SunmiHandler) {
                            activePrinter = printer
                            commandApi = try { printer.commandApi() } catch (_: Exception) { null }
                            queryApi = try { printer.queryApi() } catch (_: Exception) { null }
                            cashDrawerApi = try { printer.cashDrawerApi() } catch (_: Exception) { null }
                            lineApi = try { printer.lineApi() } catch (_: Exception) { null }
                        }
                        if (hasResponded.compareAndSet(false, true)) {
                            scope.launch(Dispatchers.Main) {
                                onSuccess(printer, commandApi)
                            }
                        }
                    } else {
                        if (hasResponded.compareAndSet(false, true)) {
                            scope.launch(Dispatchers.Main) {
                                onError("NO_PRINTER", "No default Sunmi printer found on this device.")
                            }
                        }
                    }
                }

                override fun onPrinters(printers: List<Printer>?) {
                    // Default inner printer handled in onDefPrinter
                }
            })
        } catch (e: SdkException) {
            mainHandler.removeCallbacks(timeoutRunnable)
            if (hasResponded.compareAndSet(false, true)) {
                onError("SUNMI_INIT_FAILED", "Failed to initialize Sunmi Printer SDK: ${e.message}")
            }
        } catch (e: Exception) {
            mainHandler.removeCallbacks(timeoutRunnable)
            if (hasResponded.compareAndSet(false, true)) {
                onError("UNKNOWN", e.message ?: "Unknown error initializing Sunmi printer SDK.")
            }
        }
    }

    private fun connect(result: MethodChannel.Result) {
        ensurePrinterConnected(
            onSuccess = { _, _ -> result.success(true) },
            onError = { code, msg -> result.error(code, msg, null) }
        )
    }

    private fun mapAlign(align: String?): Align {
        return when (align?.uppercase()) {
            "CENTER" -> Align.CENTER
            "RIGHT" -> Align.RIGHT
            else -> Align.LEFT
        }
    }

    private fun printReceipt(call: MethodCall, result: MethodChannel.Result) {
        val ops = call.argument<List<Map<String, Any>>>("ops")
        val is58mm = call.argument<Boolean>("is58mm") ?: false
        if (ops == null || ops.isEmpty()) {
            result.success(true)
            return
        }

        ensurePrinterConnected(
            onSuccess = { _, cmd ->
                scope.launch(Dispatchers.IO) {
                    try {
                        val lApi = lineApi ?: activePrinter?.lineApi()
                        if (lApi != null) {
                            for (op in ops) {
                                val type = op["type"] as? String ?: continue
                                when (type) {
                                    "text" -> {
                                        val text = op["text"] as? String ?: ""
                                        val alignStr = op["align"] as? String
                                        val bold = op["bold"] as? Boolean ?: false
                                        val fontSize = (op["fontSize"] as? Number)?.toInt() ?: 24
                                        val align = mapAlign(alignStr)
                                        val style = TextStyle.getStyle().apply {
                                            setAlign(align)
                                            setTextSize(fontSize)
                                            enableBold(bold)
                                        }
                                        lApi.initLine(BaseStyle.getStyle().setAlign(align))
                                        try {
                                            sunmiPrinterService?.let { svc ->
                                                val m = svc.javaClass.methods.firstOrNull { it.name == "setFontSize" && it.parameterTypes.isNotEmpty() }
                                                if (m != null) {
                                                    if (m.parameterTypes.size == 2) {
                                                        m.invoke(svc, fontSize.toFloat(), null)
                                                    } else if (m.parameterTypes.size == 1) {
                                                        m.invoke(svc, fontSize.toFloat())
                                                    }
                                                }
                                            }
                                        } catch (_: Exception) {}
                                        lApi.printText(text + "\n", style)
                                    }
                                    "divider" -> {
                                        val character = op["character"] as? String ?: "-"
                                        val charToUse = if (character.isEmpty()) "-" else character.take(1)
                                        val cols = if (is58mm) 32 else 48
                                        val dashes = charToUse.repeat(cols) + "\n"
                                        val style = TextStyle.getStyle().apply {
                                            setAlign(Align.CENTER)
                                            setTextSize(24)
                                        }
                                        lApi.initLine(BaseStyle.getStyle().setAlign(Align.CENTER))
                                        lApi.printText(dashes, style)
                                    }
                                    "row" -> {
                                        val left = op["left"] as? String ?: ""
                                        val right = op["right"] as? String ?: ""
                                        val bold = op["bold"] as? Boolean ?: false
                                        val fontSize = (op["fontSize"] as? Number)?.toInt() ?: 24
                                        val leftStyle = TextStyle.getStyle().apply {
                                            setAlign(Align.LEFT)
                                            setTextSize(fontSize)
                                            enableBold(bold)
                                        }
                                        val rightStyle = TextStyle.getStyle().apply {
                                            setAlign(Align.RIGHT)
                                            setTextSize(fontSize)
                                            enableBold(bold)
                                        }
                                        val widths = if (is58mm) intArrayOf(20, 12) else intArrayOf(34, 14)
                                        lApi.printTexts(arrayOf(left, right), widths, arrayOf(leftStyle, rightStyle))
                                    }
                                    "columns" -> {
                                        val textsList = (op["texts"] as? List<*>)?.map { it?.toString() ?: "" } ?: emptyList()
                                        val widthsList = (op["widths"] as? List<*>)?.map { (it as? Number)?.toInt() ?: 1 } ?: emptyList()
                                        val alignsList = (op["aligns"] as? List<*>)?.map { it?.toString() } ?: emptyList()
                                        val bold = op["bold"] as? Boolean ?: false
                                        val fontSize = (op["fontSize"] as? Number)?.toInt() ?: 24

                                        val textsArray = textsList.toTypedArray()
                                        val widthsArray = widthsList.toIntArray()
                                        val stylesArray = Array(textsList.size) { i ->
                                            val colAlign = if (i < alignsList.size) mapAlign(alignsList[i]) else Align.LEFT
                                            TextStyle.getStyle().apply {
                                                setAlign(colAlign)
                                                setTextSize(fontSize)
                                                enableBold(bold)
                                            }
                                        }
                                        lApi.printTexts(textsArray, widthsArray, stylesArray)
                                    }
                                    "qr" -> {
                                        val data = op["data"] as? String ?: ""
                                        val size = (op["size"] as? Number)?.toInt() ?: 4
                                        val alignStr = op["align"] as? String
                                        val qrStyle = QrStyle.getStyle().apply {
                                            setDot(size)
                                            setAlign(mapAlign(alignStr))
                                            setErrorLevel(ErrorLevel.M)
                                        }
                                        lApi.printQrCode(data, qrStyle)
                                    }
                                    "barcode" -> {
                                        val data = op["data"] as? String ?: ""
                                        val height = (op["height"] as? Number)?.toInt() ?: 64
                                        val alignStr = op["align"] as? String
                                        val barcodeStyle = BarcodeStyle.getStyle().apply {
                                            setBarHeight(height)
                                            setDotWidth(2)
                                            setReadable(HumanReadable.POS_TWO)
                                            setAlign(mapAlign(alignStr))
                                            setSymbology(Symbology.CODE128)
                                        }
                                        lApi.printBarCode(data, barcodeStyle)
                                    }
                                    "feed" -> {
                                        val lines = (op["lines"] as? Number)?.toInt()?.coerceIn(1, 255) ?: 1
                                        // LineApi's DividingLine.EMPTY parameter is pixel/dot height, not line count.
                                        // Standard thermal receipt line height is 32 dots (~4.0 mm) at 203 DPI.
                                        lApi.printDividingLine(DividingLine.EMPTY, lines * 32)
                                    }
                                    "cut" -> {
                                        lApi.autoOut()
                                    }
                                    "drawer" -> {
                                        openDrawerInternal(cmd)
                                    }
                                }
                            }

                            try {
                                sunmiPrinterService?.let { svc ->
                                    val m = svc.javaClass.methods.firstOrNull { it.name == "setFontSize" && it.parameterTypes.isNotEmpty() }
                                    if (m != null) {
                                        if (m.parameterTypes.size == 2) {
                                            m.invoke(svc, 24.0f, null)
                                        } else if (m.parameterTypes.size == 1) {
                                            m.invoke(svc, 24.0f)
                                        }
                                    }
                                }
                            } catch (_: Exception) {}
                        } else {
                            result.error("LINE_API_UNAVAILABLE", "Sunmi LineApi is not available on this printer.", null)
                            return@launch
                        }

                        withContext(Dispatchers.Main) {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("PRINT_FAILED", "Failed to print receipt via Sunmi LineApi: ${e.message}", null)
                        }
                    }
                }
            },
            onError = { code, msg -> result.error(code, msg, null) }
        )
    }

    private fun write(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null || bytes.isEmpty()) {
            result.success(true)
            return
        }

        ensurePrinterConnected(
            onSuccess = { _, cmd ->
                if (cmd == null) {
                    result.error("NOT_CONNECTED", "Sunmi command API is not available.", null)
                    return@ensurePrinterConnected
                }
                scope.launch(Dispatchers.IO) {
                    try {
                        cmd.sendEscCommand(bytes)
                        withContext(Dispatchers.Main) {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("WRITE_FAILED", "Failed to transmit ESC/POS command to Sunmi printer: ${e.message}", null)
                        }
                    }
                }
            },
            onError = { code, msg -> result.error(code, msg, null) }
        )
    }

    private fun disconnect(result: MethodChannel.Result) {
        synchronized(this@SunmiHandler) {
            activePrinter = null
            commandApi = null
            queryApi = null
            cashDrawerApi = null
            lineApi = null
        }
        result.success(null)
    }

    private fun getPaperWidth(result: MethodChannel.Result) {
        val q = queryApi
        if (q != null) {
            try {
                val paperInfo = q.getInfo(PrinterInfo.PAPER)?.toString() ?: ""
                result.success(if (paperInfo.contains("58")) 58 else 80)
                return
            } catch (_: Exception) {}
        }

        ensurePrinterConnected(
            onSuccess = { _, _ ->
                val paperInfo = queryApi?.getInfo(PrinterInfo.PAPER)?.toString() ?: ""
                result.success(if (paperInfo.contains("58")) 58 else 80)
            },
            onError = { _, _ ->
                // Safe default fallback to 80 mm (standard for desktop POS like Sunmi D3)
                result.success(80)
            }
        )
    }

    private fun getStatus(result: MethodChannel.Result) {
        ensurePrinterConnected(
            onSuccess = { _, _ ->
                try {
                    val status = queryApi?.status?.name ?: "NORMAL"
                    result.success(status)
                } catch (e: Exception) {
                    result.error("QUERY_FAILED", e.message, null)
                }
            },
            onError = { code, msg -> result.error(code, msg, null) }
        )
    }

    private fun openDrawerInternal(cmd: CommandApi?): Boolean {
        var triggered = false

        // Path 1: Official SunmiPrinterService AIDL (Sunmi's primary hardware method for desktop RJ12 ports)
        try {
            val service = sunmiPrinterService
            if (service != null) {
                service.openDrawer(null)
                triggered = true
            } else {
                InnerPrinterManager.getInstance().bindService(context, object : InnerPrinterCallback() {
                    override fun onConnected(s: SunmiPrinterService?) {
                        sunmiPrinterService = s
                        try {
                            s?.openDrawer(null)
                        } catch (_: Exception) {}
                    }
                    override fun onDisconnected() {
                        sunmiPrinterService = null
                    }
                })
                triggered = true
            }
        } catch (_: Exception) {}

        // Path 2: Sunmi PrinterX CashDrawerApi
        val drawer = cashDrawerApi
        if (drawer != null) {
            try {
                drawer.open(null)
                triggered = true
            } catch (_: Exception) {}
        }

        // Path 3: Direct ESC/POS hardware pulses sent to printer controller
        if (cmd != null) {
            try {
                cmd.sendEscCommand(byteArrayOf(0x1B, 0x70, 0x00, 0x32, 0xFA.toByte()))
                triggered = true
            } catch (_: Exception) {}

            try {
                cmd.sendEscCommand(byteArrayOf(0x1B, 0x70, 0x01, 0x32, 0xFA.toByte()))
                triggered = true
            } catch (_: Exception) {}

            try {
                cmd.sendEscCommand(byteArrayOf(0x10, 0x14, 0x00, 0x00, 0x00))
                triggered = true
            } catch (_: Exception) {}

            try {
                cmd.sendEscCommand(byteArrayOf(0x10, 0x14, 0x01, 0x00, 0x01))
                triggered = true
            } catch (_: Exception) {}

            try {
                cmd.sendEscCommand(byteArrayOf(0x10, 0x14, 0x01, 0x01, 0x01))
                triggered = true
            } catch (_: Exception) {}
        }
        return triggered
    }

    /**
     * Kicks open the connected cash drawer.
     * Executes all hardware actuation paths to guarantee the drawer opens across all Sunmi models:
     *
     * 1. SunmiPrinterService.openDrawer(null) via InnerPrinterManager (official hardware AIDL for desktop POS RJ12 port)
     * 2. PrinterSdk CashDrawerApi.open(null) via PrinterX
     * 3. Separate ESC/POS pulses (Pin 2 with 100ms width, Pin 5 with 100ms width, and Sunmi DLE DC4 pulse) sent individually.
     */
    private fun openDrawer(result: MethodChannel.Result) {
        ensurePrinterConnected(
            onSuccess = { _, cmd ->
                scope.launch(Dispatchers.IO) {
                    val triggered = openDrawerInternal(cmd)
                    withContext(Dispatchers.Main) {
                        if (triggered) {
                            result.success(true)
                        } else {
                            result.error(
                                "DRAWER_FAILED",
                                "Failed to trigger Sunmi cash drawer via service or ESC/POS pulse.",
                                null
                            )
                        }
                    }
                }
            },
            onError = { code, msg ->
                result.error(code, msg, null)
            }
        )
    }
}
