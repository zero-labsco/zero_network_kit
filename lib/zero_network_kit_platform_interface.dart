import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'zero_network_kit_method_channel.dart';

/// ZeroNetworkKit 平台接口基类 / ZeroNetworkKit platform interface base class.
///
/// 定义与原生平台交互的抽象方法，各平台实现需继承此类并通过
/// [ZeroNetworkKitPlatform.instance] 注册。/ Defines the abstract surface used to
/// talk to the native platform; platform implementations must extend this class
/// and register themselves through [ZeroNetworkKitPlatform.instance].
abstract class ZeroNetworkKitPlatform extends PlatformInterface {
  /// 构造 [ZeroNetworkKitPlatform] / Constructs a [ZeroNetworkKitPlatform].
  ZeroNetworkKitPlatform() : super(token: _token);

  /// 接口标识 Token，用于校验平台实现的合法性 / Token used to verify platform
  /// implementations.
  static final Object _token = Object();

  /// 默认平台实例，使用 MethodChannel 实现 / Default platform instance backed by
  /// the method channel implementation.
  static ZeroNetworkKitPlatform _instance = MethodChannelZeroNetworkKit();

  /// 获取默认平台实例 / Get the default platform instance.
  static ZeroNetworkKitPlatform get instance => _instance;

  /// 设置平台实例 / Set the platform instance.
  ///
  /// 平台实现应在注册时传入自己的实现类 / Platform implementations should pass
  /// their own class when registering.
  static set instance(ZeroNetworkKitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// 获取平台版本信息，例如 `Android 14` / `iOS 18.0` /
  /// Get the platform version, e.g. `Android 14` / `iOS 18.0`.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  /// 获取原生网络详情 / Get native network details.
  ///
  /// 返回的 Map 可包含以下键（缺失或不可用时为 `null`）/
  /// The returned map may contain the following keys (absent or `null` when
  /// unavailable):
  /// `ipAddress`、`ipv6Address`、`macAddress`、`gateway`、`ssid`、`bssid`、
  /// `signalStrength`（dBm，[int]）、`isVpn`（[bool]）。
  Future<Map<String, Object?>?> getNetworkDetails() {
    throw UnimplementedError('getNetworkDetails() has not been implemented.');
  }
}
