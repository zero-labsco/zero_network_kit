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
    details["gateway"] = defaultGateway()
    details["isVpn"] = hasTunnelInterface()
    return details
  }

  // <sys/sysctl.h> / <net/route.h> 的常量，此处显式声明，避免依赖 Swift 对 C
  // 宏的导入方式 / Constants from <sys/sysctl.h> / <net/route.h>, restated
  // explicitly so the code does not depend on how Swift imports C macros.
  private static let netRtFlags: Int32 = 2  // NET_RT_FLAGS
  private static let rtfGateway: Int32 = 0x2  // RTF_GATEWAY
  private static let rtmVersion: UInt8 = 5  // RTM_VERSION
  private static let rtaDst: Int32 = 0x1  // RTA_DST
  private static let rtaGateway: Int32 = 0x2  // RTA_GATEWAY

  // rt_msghdr 在 Darwin 上的固定布局：32 字节头部字段 + 48 字节 rt_metrics，
  // sockaddr 数组从第 80 字节开始 / Fixed Darwin layout of rt_msghdr: 32 bytes
  // of header fields plus 48 bytes of rt_metrics, so the sockaddr array starts
  // at byte 80.
  private static let rtmSockaddrOffset = 80

  /// 读取默认网关（IPv4）/ Reads the default IPv4 gateway.
  ///
  /// 与 `netstat -rn` 同源：直接读 `sysctl` 路由表，**不需要任何权限、
  /// entitlement 或额外 framework**。解析失败时返回 `nil`，由 Dart 侧按既有
  /// 约定优雅降级 / Same source as `netstat -rn`: the `sysctl` routing table is
  /// read directly and **no permission, entitlement or extra framework is
  /// required**. Parsing failures return `nil`, which the Dart side degrades
  /// gracefully as usual.
  private func defaultGateway() -> String? {
    var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, Self.netRtFlags, Self.rtfGateway]
    var length = 0

    // 先取所需缓冲区大小，再真正读取 / Query the buffer size first, then read.
    guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else {
      return nil
    }

    var buffer = [UInt8](repeating: 0, count: length)
    guard sysctl(&mib, UInt32(mib.count), &buffer, &length, nil, 0) == 0 else {
      return nil
    }

    var offset = 0
    while offset + Self.rtmSockaddrOffset + 4 <= length {
      // rtm_msglen 位于消息开头 2 字节 / rtm_msglen sits in the first 2 bytes.
      let messageLength = Int(buffer[offset]) << 8 | Int(buffer[offset + 1])
      guard messageLength >= Self.rtmSockaddrOffset + 4,
        offset + messageLength <= length
      else { break }

      // rtm_version 位于 +2，rtm_flags 位于 +6，rtm_addrs 位于 +10 /
      // rtm_version at +2, rtm_flags at +6, rtm_addrs at +10.
      guard buffer[offset + 2] == Self.rtmVersion else {
        offset += messageLength
        continue
      }

      let flags = Self.readInt32(buffer, at: offset + 6)
      let addrs = Self.readInt32(buffer, at: offset + 10)
      guard flags & Self.rtfGateway != 0, addrs & Self.rtaGateway != 0 else {
        offset += messageLength
        continue
      }

      // 按 RTA 位掩码顺序跳过前面的 sockaddr，直到网关地址 / Walk the sockaddrs
      // in RTA bitmask order until the gateway one is reached.
      var cursor = offset + Self.rtmSockaddrOffset
      for bit in [Self.rtaDst, Self.rtaGateway] where addrs & bit != 0 {
        if bit == Self.rtaGateway {
          return Self.socketAddressString(buffer, at: cursor)
        }
        cursor += Self.sockaddrStride(buffer, at: cursor)
      }
      offset += messageLength
    }
    return nil
  }

  /// 按主机字节序读取一个 32 位整数 / Reads a 32-bit integer in host byte order.
  private static func readInt32(_ buffer: [UInt8], at offset: Int) -> Int32 {
    guard offset + 4 <= buffer.count else { return 0 }
    return Int32(
      bitPattern: UInt32(buffer[offset]) << 24 | UInt32(buffer[offset + 1]) << 16
        | UInt32(buffer[offset + 2]) << 8 | UInt32(buffer[offset + 3])
    )
  }

  /// 路由消息中 sockaddr 的步进长度（按 4 字节对齐）/
  /// Stride of a sockaddr inside a routing message (padded to 4 bytes).
  private static func sockaddrStride(_ buffer: [UInt8], at offset: Int) -> Int {
    guard offset < buffer.count else { return 0 }
    let raw = Int(buffer[offset])
    let length = raw > 0 ? raw : MemoryLayout<sockaddr>.size
    return (length + 3) & ~3
  }

  /// 把缓冲区中某个 sockaddr 转换为点分字符串 /
  /// Converts a sockaddr inside the buffer into a dotted address string.
  private static func socketAddressString(_ buffer: [UInt8], at offset: Int) -> String? {
    guard offset + 2 <= buffer.count else { return nil }
    let family = Int32(buffer[offset + 1])
    guard family == AF_INET else { return nil }

    let size = MemoryLayout<sockaddr_in>.size
    guard offset + size <= buffer.count else { return nil }

    var storage = [UInt8](repeating: 0, count: size)
    for index in 0..<size { storage[index] = buffer[offset + index] }

    return storage.withUnsafeBufferPointer { source in
      source.baseAddress!.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let status = getnameinfo(
          address,
          socklen_t(storage[0]),
          &host,
          socklen_t(host.count),
          nil,
          0,
          NI_NUMERICHOST
        )
        guard status == 0 else { return nil }
        return String(cString: host)
      }
    }
  }

  /// 读取指定网卡指定地址族的地址 / Reads an address of a given family from an
  /// interface.
  private func address(forInterface name: String, family: Int32) -> String? {
    var interfaces: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
    defer { freeifaddrs(interfaces) }

    for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
      let interface = pointer.pointee
      guard let socketAddress = interface.ifa_addr else { continue }
      guard socketAddress.pointee.sa_family == UInt8(family) else { continue }
      guard String(cString: interface.ifa_name) == name else { continue }
      // 命中即返回，不再继续遍历：此前会一路走到最后一个匹配项 / Return on the
      // first hit instead of walking to the last match.
      return numericAddress(socketAddress)
    }
    return nil
  }

  /// 把套接字地址转成点分 / 冒分字符串 / Renders a socket address as text.
  private func numericAddress(_ socketAddress: UnsafePointer<sockaddr>) -> String? {
    // `sa_len` 并非总被填充，缺失时按地址族推断长度 / `sa_len` is not always
    // populated; fall back to the family's struct size when it is zero.
    let length: socklen_t =
      socketAddress.pointee.sa_len > 0
        ? socklen_t(socketAddress.pointee.sa_len)
        : (socketAddress.pointee.sa_family == UInt8(AF_INET)
          ? socklen_t(MemoryLayout<sockaddr_in>.size)
          : socklen_t(MemoryLayout<sockaddr_in6>.size))

    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    let status = getnameinfo(
      socketAddress,
      length,
      &host,
      socklen_t(host.count),
      nil,
      0,
      NI_NUMERICHOST
    )
    guard status == 0 else { return nil }

    let address = String(cString: host)
    // IPv6 可能带 scope 后缀（如 fe80::1%en0），统一去掉。
    guard let separatorIndex = address.firstIndex(of: "%") else { return address }
    return String(address[..<separatorIndex])
  }

  /// 判断是否存在承载真实隧道的虚拟网卡 / Detects a virtual interface that
  /// actually carries a tunnel.
  ///
  /// iOS 常驻多个 `utun` 接口（AWDL、AirDrop、iCloud 私隐中转等），仅按前缀判断
  /// 会把 `isVpn` 常年置为 true。此处要求接口额外拥有**可路由的 IPv4 地址**才
  /// 认定为 VPN —— 系统常驻的 utun 通常只带 IPv6 链路本地地址 /
  /// iOS keeps several `utun` interfaces alive (AWDL, AirDrop, Private Relay…),
  /// so a prefix match alone reports `isVpn` as true almost always. An interface
  /// only counts as a VPN when it also owns a **routable IPv4 address**; the
  /// system-resident ones typically carry a link-local IPv6 address only.
  private func hasTunnelInterface() -> Bool {
    var interfaces: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&interfaces) == 0, let first = interfaces else { return false }
    defer { freeifaddrs(interfaces) }

    for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
      let interface = pointer.pointee
      let name = String(cString: interface.ifa_name)
      let isExplicitTunnel =
        name.hasPrefix("tap") || name.hasPrefix("tun")
          || name.hasPrefix("ppp") || name.hasPrefix("ipsec")
      guard isExplicitTunnel || name.hasPrefix("utun") else { continue }
      guard let socketAddress = interface.ifa_addr,
        socketAddress.pointee.sa_family == UInt8(AF_INET),
        let address = numericAddress(socketAddress)
      else { continue }

      // tap/tun/ppp/ipsec 一旦出现即视为隧道 / An explicit tunnel interface
      // counts as soon as it shows up.
      if isExplicitTunnel { return true }
      // utun 还需排除链路本地与回环地址，否则 AWDL / AirDrop 会被误判 /
      // For `utun`, filter out link-local and loopback so AWDL / AirDrop are not
      // mistaken for a VPN.
      if !address.hasPrefix("169.254") && !address.hasPrefix("127.") { return true }
    }
    return false
  }
}
