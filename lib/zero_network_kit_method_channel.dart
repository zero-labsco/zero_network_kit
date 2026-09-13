import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'zero_network_kit_platform_interface.dart';

/// 使用 MethodChannel 实现的平台接口 / Platform interface implementation backed by
/// a [MethodChannel].
class MethodChannelZeroNetworkKit extends ZeroNetworkKitPlatform {
  /// 与原生平台交互的 MethodChannel / The method channel used to interact with
  /// the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('zero_network_kit');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<Map<String, Object?>?> getNetworkDetails() async {
    final details = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getNetworkDetails',
    );
    if (details == null) return null;
    return details.map((key, value) => MapEntry(key.toString(), value));
  }
}
