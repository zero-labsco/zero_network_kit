import Flutter
import UIKit

/// ZeroNetworkKit 原生实现 / Native side of ZeroNetworkKit.
///
/// Dart 侧负责绝大多数诊断逻辑（TCP 探测、DNS 报文、测速），原生侧只补充平台
/// 版本与当前 Wi-Fi 接口的地址信息 / The Dart layer performs most of the
/// diagnostics; the native side only adds the platform version and the address
/// of the active Wi-Fi interface.
///
/// 注意：SSID / BSSID 需要 Access WiFi Information 权限与定位授权，出于隐私
/// 考虑此处不申请，对应字段会在 Dart 侧保持 `null` /
/// Note: SSID / BSSID require the Access WiFi Information entitlement and
/// location authorisation; to stay privacy-friendly they are not requested here,
/// so those fields remain `null` on the Dart side.
public class ZeroNetworkKitPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "zero_network_kit",
      binaryMessenger: registrar.messenger()
    )
    let instance = ZeroNetworkKitPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "getNetworkDetails":
      result(networkDetails())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 汇总当前网络的可读属性 / Collects the readable properties of the network.
  ///
  /// iOS 不再暴露稳定的 MAC 地址（自 iOS 7 起返回固定值 `02:00:00:00:00:00`），
  /// 因此不返回 `macAddress`，由 Dart 侧通过 `dart:io` 兜底 /
  /// iOS no longer exposes a usable MAC address (it has been a constant value
  /// since iOS 7), so `macAddress` is omitted and the Dart layer falls back to
  /// `dart:io`.
  private func networkDetails() -> [String: Any?] {
    var details: [String: Any?] = [:]
    details["ipAddress"] = address(forInterface: "en0", family: AF_INET)
    details["ipv6Address"] = address(forInterface: "en0", family: AF_INET6)
    details["isVpn"] = hasTunnelInterface()
    return details
  }

  /// 读取指定网卡指定地址族的地址 / Reads an address of a given family from an
  /// interface.
  private func address(forInterface name: String, family: Int32) -> String? {
    var address: String?
    var interfaces: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
    defer { freeifaddrs(interfaces) }

    for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
      let interface = pointer.pointee
      guard let socketAddress = interface.ifa_addr else { continue }
      guard socketAddress.pointee.sa_family == UInt8(family) else { continue }
      guard String(cString: interface.ifa_name) == name else { continue }

      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      let length = socklen_t(socketAddress.pointee.sa_len)
      let status = getnameinfo(
        socketAddress,
        length,
        &host,
        socklen_t(host.count),
        nil,
        0,
        NI_NUMERICHOST
      )
      if status == 0 {
        address = String(cString: host)
        // IPv6 可能带 scope 后缀（如 fe80::1%en0），统一去掉。
        if let separatorIndex = address?.firstIndex(of: "%") {
          address = String(address![..<separatorIndex])
        }
      }
    }
    return address
  }

  /// 简单判断是否存在 VPN 隧道网卡 / Rough check for a VPN tunnel interface.
  private func hasTunnelInterface() -> Bool {
    var interfaces: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&interfaces) == 0, let first = interfaces else { return false }
    defer { freeifaddrs(interfaces) }

    for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
      let name = String(cString: pointer.pointee.ifa_name)
      if name.hasPrefix("utun") || name.hasPrefix("tap") || name.hasPrefix("tun") {
        return true
      }
    }
    return false
  }
}
