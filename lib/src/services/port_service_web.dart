import '../models/port_check_result.dart';

/// Web 端 TCP 端口连通性检测服务 / TCP port reachability service for the web.
///
/// 浏览器禁止任意出站 TCP 连接，因此端口检测在 Web 上不可用；所有方法均返回
/// 表示“不可用”的结果，不抛异常 / Browsers forbid arbitrary outbound TCP
/// connections, so port checks are unavailable on the web; every method returns a
/// result that marks the capability as unavailable instead of throwing.
class PortService {
  /// 构造 [PortService] / Creates a [PortService].
  const PortService({this.defaultTimeout = const Duration(seconds: 3)});

  /// 单次连接默认超时 / Default timeout of a single connection attempt.
  final Duration defaultTimeout;

  /// 检测单个端口是否可连接 / Checks whether a single port accepts connections.
  Future<PortCheckResult> checkPort({
    required String host,
    required int port,
    Duration? timeout,
  }) async {
    return PortCheckResult(
      host: host,
      port: port,
      isOpen: false,
      responseTime: Duration.zero,
      errorMessage: 'TCP port scanning is not available on the web platform.',
      timestamp: DateTime.now(),
    );
  }

  /// [checkPort] 的布尔快捷方式 / Boolean shorthand for [checkPort].
  Future<bool> isPortOpen({
    required String host,
    required int port,
    Duration? timeout,
  }) async => false;

  /// 并发扫描多个端口 / Scans multiple ports with bounded concurrency.
  Future<List<PortCheckResult>> scanPorts({
    required String host,
    List<int> ports = const <int>[80, 443],
    Duration? timeout,
    int concurrency = 12,
  }) async {
    return ports
        .map(
          (port) => PortCheckResult(
            host: host,
            port: port,
            isOpen: false,
            responseTime: Duration.zero,
            errorMessage:
                'TCP port scanning is not available on the web platform.',
            timestamp: DateTime.now(),
          ),
        )
        .toList(growable: false);
  }
}
