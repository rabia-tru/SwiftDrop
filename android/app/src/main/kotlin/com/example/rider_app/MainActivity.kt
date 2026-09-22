package com.example.rider_app

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "battery_optimization"
    private val NET_CHANNEL = "network_binding"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Enable edge-to-edge display
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // Bind the whole app process to the WiFi network whenever WiFi is
        // available. Fix for: "mobile data ON → app can't reach the PC's LAN
        // backend even though internet works". Android's default route is
        // cellular, and LAN IPs (192.168.x.x) are unreachable over mobile
        // data — binding sockets to WiFi pins all traffic to that network.
        // (bindProcessToNetwork requires API 23+.)
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    val caps = cm.getNetworkCapabilities(network)
                    if (caps != null && caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI)) {
                        cm.bindProcessToNetwork(network)
                    }
                }

                override fun onLost(network: Network) {
                    // WiFi gone → clear the binding so the app falls back to the
                    // default network instead of holding a dead socket route.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                        cm.boundNetworkForProcess == network) {
                        cm.bindProcessToNetwork(null)
                    }
                }
            }

            val request = android.net.NetworkRequest.Builder()
                .addTransportType(android.net.NetworkCapabilities.TRANSPORT_WIFI)
                .build()
            cm.registerNetworkCallback(request, networkCallback)

            // If WiFi is already connected when the app starts, bind immediately
            // (registerNetworkCallback only fires on changes).
            try {
                val active = cm.activeNetwork
                val caps = active?.let { cm.getNetworkCapabilities(it) }
                if (caps != null && caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI)) {
                    cm.bindProcessToNetwork(active)
                }
            } catch (_: Exception) {}
        }

        // Keep the binding channel so Dart can re-assert / query state
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "rebind" -> {
                        try {
                            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            val active = cm.activeNetwork
                            val caps = active?.let { cm.getNetworkCapabilities(it) }
                            val bound = if (caps != null && caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI)) {
                                cm.bindProcessToNetwork(active)
                                true
                            } else {
                                cm.bindProcessToNetwork(null)
                                false
                            }
                            result.success(bound)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "isOnWifi" -> {
                        try {
                            val active = cm.activeNetwork
                            val caps = active?.let { cm.getNetworkCapabilities(it) }
                            result.success(caps != null && caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI))
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        
        // Enable hardware acceleration for smooth rendering
        window.setFlags(
            android.view.WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            android.view.WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        result.success(isIgnoringBatteryOptimizations())
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations(result)
                    }
                    "openBatterySettings" -> {
                        openBatterySettings()
                        result.success(true)
                    }
                    "isPowerSaveMode" -> {
                        result.success(isPowerSaveMode())
                    }
                    "openBatterySaverSettings" -> {
                        openBatterySaverSettings()
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            return powerManager.isIgnoringBatteryOptimizations(packageName)
        }
        return true // Pre-M devices don't have this restriction
    }

    private fun requestIgnoreBatteryOptimizations(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            } else {
                result.success(true)
            }
        } else {
            result.success(true)
        }
    }

    private fun isPowerSaveMode(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            return powerManager.isPowerSaveMode
        }
        return false
    }

    private fun openBatterySaverSettings() {
        try {
            val intent = Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to general battery settings
            try {
                val intent = Intent(Settings.ACTION_SETTINGS)
                startActivity(intent)
            } catch (_: Exception) {}
        }
    }

    private fun openBatterySettings() {
        try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to app settings
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        }
    }
}
