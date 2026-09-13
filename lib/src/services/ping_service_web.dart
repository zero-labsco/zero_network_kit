import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/ping_result.dart';

/// Web 端网络延迟（Ping）测试服务 / Latency (ping) test service for the web.
///
/// 浏览器无法建立任意 TCP / ICMP 连接，因此：
/// - [PingMode.tcp] 退化为对目标主机发起 HTTPS 请求并测量往返耗时；
/// - [PingMode.icmp] 在 Web 上不可用时抛出 [UnsupportedError] /
/// Browsers cannot open arbitrary TCP or ICMP connections, so on the web:
/// - [PingMode.tcp] degrades to measuring the round trip of an HTTPS request;
/// - [PingMode.icmp] is unavailable and throws [UnsupportedError].
class PingService {
  /// 构造 [PingService] / Creates a [PingService].
  const PingService({this.defaultPort = 443});

  /// TCP 模式下默认探测端口 / Default probe port in TCP mode.
  final int defaultPort;

  /// 执行 Ping 测试 / Runs a ping test.
  Future<PingResult> ping({
    required String host,
    int count = 4,
    Duration timeout = const Duration(seconds: 3),
    Duration interval = const Duration(milliseconds: 200),
    int? port,
    PingMode mode = PingMode.tcp,
  }) async {
    if (count <= 0) {
      return PingResult(
        host: host,
        sent: 0,
        received: 0,
        times: const <double>[],
        timestamp: DateTime.now(),
        port: port ?? defaultPort,
        mode: mode,
      );
    }

    if (mode == PingMode.icmp) {
      return _icmpPing();
    }
    return _tcpPing(
      host: host,
      count: count,
      timeout: timeout,
      interval: interval,
      port: port ?? defaultPort,
    );
  }

  Future<PingResult> _tcpPing({
    required String host,
    required int count,
    required Duration timeout,
    required Duration interval,
    required int port,
  }) async {
    final times = <double>[];
    for (var i = 0; i < count; i++) {
      if (i > 0 && interval > Duration.zero) {
        await Future<void>.delayed(interval);
      }
      final elapsed = await _probeHttp(host, port, timeout);
      if (elapsed != null) times.add(elapsed);
    }

    return PingResult(
      host: host,
      sent: count,
      received: times.length,
      times: times,
      timestamp: DateTime.now(),
      port: port,
      mode: PingMode.tcp,
    );
  }

  /// 通过一次 HTTPS 请求测量往返耗时 / Measures the round trip via an HTTPS request.
  ///
  /// 失败（CORS、证书、网络错误）时返回 `null`，视为丢包 / Returns `null` on any
  /// failure (CORS, certificate, network), which is treated as packet loss.
  static Future<double?> _probeHttp(
    String host,
    int port,
    Duration timeout,
  ) async {
    final uri = Uri(
      scheme: port == 80 ? 'http' : 'https',
      host: host,
      port: port,
      path: '/',
    );
    final client = http.Client();
    final stopwatch = Stopwatch()..start();
    try {
      final response = await client
          .get(uri, headers: <String, String>{'Cache-Control': 'no-cache'})
          .timeout(timeout);
      stopwatch.stop();
      if (response.statusCode >= 400) return null;
      return stopwatch.elapsedMicroseconds / 1000;
    } catch (_) {
      stopwatch.stop();
      return null;
    } finally {
      client.close();
    }
  }

  Future<PingResult> _icmpPing() async {
    throw UnsupportedError(
      'PingMode.icmp is unavailable on the web platform; use PingMode.tcp.',
    );
  }
}
