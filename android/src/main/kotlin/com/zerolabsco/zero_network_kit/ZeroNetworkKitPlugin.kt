package com.zerolabsco.zero_network_kit

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.net.Inet4Address
import java.net.Inet6Address

/**
 * ZeroNetworkKit 原生实现 / Native side of ZeroNetworkKit.
 *
 * Dart 侧负责绝大多数诊断逻辑（TCP 探测、DNS 报文、测速），原生侧只补充那些必须
 * 通过系统服务才能获取的信息：平台版本、当前网络的 IP / 网关 / VPN 状态以及
 * Wi-Fi 的 SSID / BSSID / 信号强度 / The Dart layer performs most of the
 * diagnostics (TCP probes, DNS messages, throughput); the native side only adds
 * information that requires system services: platform version plus the active
 * network's IP, gateway, VPN flag and Wi-Fi SSID / BSSID / RSSI.
 */
class ZeroNetworkKitPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "zero_network_kit")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "getNetworkDetails" -> result.success(collectNetworkDetails())
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    /**
     * 汇总当前激活网络的属性 / Collects the properties of the active network.
     *
     * 缺少权限或服务不可用时对应键会被省略，Dart 侧会按 `null` 处理 /
     * Unavailable values are simply omitted; the Dart side treats them as null.
     */
    private fun collectNetworkDetails(): Map<String, Any?> {
        val details = mutableMapOf<String, Any?>()

        try {
            val connectivityManager =
                applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            val network = connectivityManager?.activeNetwork
            val capabilities = network?.let { connectivityManager.getNetworkCapabilities(it) }
            val linkProperties = network?.let { connectivityManager.getLinkProperties(it) }

            details["isVpn"] = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ?: false

            linkProperties?.let { properties ->
                fillLinkProperties(details, properties)
            }
        } catch (_: SecurityException) {
            // 缺少 ACCESS_NETWORK_STATE 权限时静默降级 / Degrade silently.
        } catch (_: Exception) {
            // 其它系统异常同样降级，保证通道调用不会失败。
        }

        try {
            fillWifiDetails(details)
        } catch (_: SecurityException) {
            // 缺少 ACCESS_WIFI_STATE / 定位权限时无法读取 SSID。
        } catch (_: Exception) {
            // 忽略。
        }

        try {
            fillMacAddress(details)
        } catch (_: Exception) {
            // Android 6.0 之后多数情况下会返回 null / usually null since API 23.
        }

        return details
    }

    /**
     * 读取物理网卡 MAC 地址 / Reads the hardware MAC address.
     *
     * Android 6.0 起该值会被系统屏蔽（多为 `02:00:00:00:00:00`），拿到可用值时
     * 才会写入 / Android masks this value since API 23; it is only reported when a
     * usable value is available.
     */
    private fun fillMacAddress(details: MutableMap<String, Any?>) {
        val interfaces = java.net.NetworkInterface.getNetworkInterfaces().toList()
        for (networkInterface in interfaces) {
            if (!networkInterface.isUp || networkInterface.isLoopback) continue
            val mac = networkInterface.hardwareAddress ?: continue
            if (mac.isEmpty()) continue
            val formatted = mac.joinToString(":") { byte -> String.format("%02x", byte) }
            if (formatted == "02:00:00:00:00:00") continue
            details["macAddress"] = formatted
            return
        }
    }

    private fun fillLinkProperties(
        details: MutableMap<String, Any?>,
        properties: LinkProperties,
    ) {
        for (linkAddress in properties.linkAddresses) {
            val address = linkAddress.address
            when (address) {
                is Inet4Address -> details.putIfAbsent("ipAddress", address.hostAddress)
                is Inet6Address -> details.putIfAbsent("ipv6Address", address.hostAddress?.substringBefore('%'))
                else -> Unit
            }
        }

        for (route in properties.routes) {
            if (!route.isDefaultRoute) continue
            val gateway = route.gateway
            if (gateway is Inet4Address) {
                details["gateway"] = gateway.hostAddress
                break
            }
        }

        properties.dnsServers.firstOrNull()?.let { dns ->
            details["dnsServer"] = dns.hostAddress
        }
    }

    @Suppress("DEPRECATION")
    private fun fillWifiDetails(details: MutableMap<String, Any?>) {
        val wifiManager =
            applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return
        val info = wifiManager.connectionInfo ?: return

        val ssid = info.ssid?.replace("\"", "")?.trim()
        if (!ssid.isNullOrEmpty() && ssid != WifiManager.UNKNOWN_SSID) {
            details["ssid"] = ssid
        }

        val bssid = info.bssid?.takeIf { it != "02:00:00:00:00:00" }
        if (!bssid.isNullOrEmpty()) {
            details["bssid"] = bssid
        }

        if (info.rssi != 0 && info.rssi != -127) {
            details["signalStrength"] = info.rssi
        }
    }
}
