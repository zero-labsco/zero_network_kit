import Cocoa
import FlutterMacOS

public class ZeroNetworkKitPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "zero_network_kit", binaryMessenger: registrar.messenger)
    let instance = ZeroNetworkKitPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "getNetworkDetails":
      // A 档：桌面原生层只返回空详情 map，IP/IPv6 由 Dart NetworkInterface 兜底，
      // SSID / 网关 / MAC / VPN 在桌面为 null。
      result([String: Any]())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
