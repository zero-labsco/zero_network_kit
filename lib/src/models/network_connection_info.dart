import 'network_type.dart';

/// 当前网络连接快照 / A snapshot of the current network connection.
class NetworkConnectionInfo {
  /// 构造 [NetworkConnectionInfo] / Creates a [NetworkConnectionInfo].
  const NetworkConnectionInfo({
    required this.isConnected,
    required this.type,
    required this.timestamp,
    this.ssid,
    this.signalStrength,
    this.ipAddress,
    this.ipv6Address,
    this.gateway,
    this.macAddress,
    this.isVpn = false,
    this.isReachable,
  });

  /// 是否存在可用网络 / Whether an active network is available.
  final bool isConnected;

  /// 连接类型 / Connection type.
  final NetworkType type;

  /// Wi-Fi SSID（无权限或非 Wi-Fi 时为 `null`）/
  /// Wi-Fi SSID (`null` without permission or when not on Wi-Fi).
  final String? ssid;

  /// Wi-Fi 信号强度，单位 dBm / Wi-Fi signal strength in dBm.
  final int? signalStrength;

  /// IPv4 地址 / Primary IPv4 address.
  final String? ipAddress;

  /// IPv6 地址 / Primary IPv6 address.
  final String? ipv6Address;

  /// 默认网关 / Default gateway address.
  final String? gateway;

  /// 物理网卡 MAC 地址 / Hardware MAC address.
  final String? macAddress;

  /// 是否处于 VPN 通道 / Whether traffic is routed through a VPN.
  final bool isVpn;

  /// 主动连通性探测结果（未探测时为 `null`）/
  /// Result of an active reachability probe (`null` when not probed).
  final bool? isReachable;

  /// 采样时间 / Sampling timestamp.
  final DateTime timestamp;

  /// 生成一份带 [isReachable] 的副本 / Returns a copy carrying [isReachable].
  NetworkConnectionInfo copyWith({bool? isReachable}) {
    return NetworkConnectionInfo(
      isConnected: isConnected,
      type: type,
      timestamp: timestamp,
      ssid: ssid,
      signalStrength: signalStrength,
      ipAddress: ipAddress,
      ipv6Address: ipv6Address,
      gateway: gateway,
      macAddress: macAddress,
      isVpn: isVpn,
      isReachable: isReachable ?? this.isReachable,
    );
  }

  /// 序列化为可 JSON 编码的 Map / Serialises to a JSON encodable map.
  Map<String, Object?> toMap() => <String, Object?>{
    'isConnected': isConnected,
    'type': type.id,
    'ssid': ssid,
    'signalStrength': signalStrength,
    'ipAddress': ipAddress,
    'ipv6Address': ipv6Address,
    'gateway': gateway,
    'macAddress': macAddress,
    'isVpn': isVpn,
    'isReachable': isReachable,
    'timestamp': timestamp.toIso8601String(),
  };

  /// 从 [toMap] 产物还原 / Restores an instance produced by [toMap].
  factory NetworkConnectionInfo.fromMap(Map<Object?, Object?> map) {
    return NetworkConnectionInfo(
      isConnected: map['isConnected'] == true,
      type: NetworkType.fromRaw(map['type']),
      ssid: map['ssid'] as String?,
      signalStrength: (map['signalStrength'] as num?)?.toInt(),
      ipAddress: map['ipAddress'] as String?,
      ipv6Address: map['ipv6Address'] as String?,
      gateway: map['gateway'] as String?,
      macAddress: map['macAddress'] as String?,
      isVpn: map['isVpn'] == true,
      isReachable: map['isReachable'] as bool?,
      timestamp:
          DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  @override
  String toString() =>
      'NetworkConnectionInfo(isConnected: $isConnected, type: ${type.id}, '
      'ssid: $ssid, ip: $ipAddress, gateway: $gateway, vpn: $isVpn)';

  @override
  bool operator ==(Object other) =>
      other is NetworkConnectionInfo &&
      other.isConnected == isConnected &&
      other.type == type &&
      other.ssid == ssid &&
      other.signalStrength == signalStrength &&
      other.ipAddress == ipAddress &&
      other.ipv6Address == ipv6Address &&
      other.gateway == gateway &&
      other.macAddress == macAddress &&
      other.isVpn == isVpn &&
      other.isReachable == isReachable;

  @override
  int get hashCode => Object.hash(
    isConnected,
    type,
    ssid,
    signalStrength,
    ipAddress,
    ipv6Address,
    gateway,
    macAddress,
    isVpn,
    isReachable,
  );
}
