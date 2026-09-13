/// 网络连接类型 / Network connection type.
enum NetworkType {
  /// 无网络 / No active network.
  none,

  /// Wi-Fi / Wi-Fi.
  wifi,

  /// 蜂窝移动网络 / Cellular network.
  mobile,

  /// 有线以太网 / Wired Ethernet.
  ethernet,

  /// VPN 通道 / VPN tunnel.
  vpn,

  /// 蓝牙共享网络 / Bluetooth tethering.
  bluetooth,

  /// 其它未识别类型 / Any other unrecognised transport.
  other;

  /// 从平台适配器返回的原始字符串解析 / Parse a raw value returned by a
  /// platform adapter.
  static NetworkType fromRaw(Object? raw) {
    final value = raw?.toString().toLowerCase().trim() ?? '';
    if (value.isEmpty) return NetworkType.none;
    if (value.contains('wifi') || value.contains('wi-fi')) {
      return NetworkType.wifi;
    }
    if (value.contains('mobile') || value.contains('cellular')) {
      return NetworkType.mobile;
    }
    if (value.contains('ethernet')) return NetworkType.ethernet;
    if (value.contains('vpn')) return NetworkType.vpn;
    if (value.contains('bluetooth')) return NetworkType.bluetooth;
    if (value.contains('none') ||
        value.contains('unknown') ||
        value.contains('unavailable')) {
      return NetworkType.none;
    }
    return NetworkType.other;
  }

  /// 是否可认为已接入网络 / Whether this transport implies an active network.
  bool get isConnected => this != NetworkType.none;

  /// 英文标识（稳定，可序列化）/ Stable English identifier (serialisable).
  String get id => name;

  /// 人类可读名称 / Human readable label.
  String get label => switch (this) {
    NetworkType.none => 'No network',
    NetworkType.wifi => 'Wi-Fi',
    NetworkType.mobile => 'Mobile',
    NetworkType.ethernet => 'Ethernet',
    NetworkType.vpn => 'VPN',
    NetworkType.bluetooth => 'Bluetooth',
    NetworkType.other => 'Other',
  };
}
