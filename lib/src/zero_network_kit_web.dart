import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'package:zero_network_kit/zero_network_kit_platform_interface.dart';

/// Web 平台实现 / Web platform implementation.
///
/// 浏览器无法提供 SSID / 网关 / MAC 等原生网络详情，因此 [getNetworkDetails]
/// 返回 `null`；[getPlatformVersion] 返回固定字符串 `Web` /
/// Browsers cannot provide native network details such as SSID / gateway / MAC,
/// so [getNetworkDetails] returns `null`, and [getPlatformVersion] returns `Web`.
class ZeroNetworkKitWeb extends ZeroNetworkKitPlatform {
  /// 注册 Web 平台实现 / Registers the web implementation.
  static void registerWith(Registrar registrar) {
    ZeroNetworkKitPlatform.instance = ZeroNetworkKitWeb();
  }

  @override
  Future<String?> getPlatformVersion() async => 'Web';

  @override
  Future<Map<String, Object?>?> getNetworkDetails() async => null;
}
