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

  /// 构造系统 `ping` 命令的参数 / Builds the arguments for the system `ping`.
  ///
  /// Web 端没有系统 `ping`，故总是抛 [UnsupportedError]；保留同名方法是为了让
  /// 两个平台分支共享同一套 API 表面（条件导出要求两侧一致）/
  /// There is no system `ping` on the web, so this always throws
  /// [UnsupportedError]; the method exists so both platform branches expose the
  /// same API surface, which conditional exports require.
  static List<String> icmpArgs({
    required String host,
    required int count,
    required Duration timeout,
    required bool isWindows,
    required bool isMacOS,
  }) {
    throw UnsupportedError(
      'PingMode.icmp is unavailable on the web platform; use PingMode.tcp.',
    );
  }

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
    // 整轮探测复用同一个客户端：每次探测都新建会在浏览器里额外付出一轮连接
    // 建立成本，把结果抬高 / One client for the whole run: a fresh client per
    // probe adds another connection setup to every sample and inflates it.
    final client = http.Client();
    final times = <double>[];
    try {
      for (var i = 0; i < count; i++) {
        if (i > 0 && interval > Duration.zero) {
          await Future<void>.delayed(interval);
        }
        final elapsed = await _probeHttp(client, host, port, timeout);
        if (elapsed != null) times.add(elapsed);
      }
    } finally {
      client.close();
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
    http.Client client,
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
    final stopwatch = Stopwatch()..start();
    try {
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] = 'zero_network_kit/1.0';
      final response = await client.send(request).timeout(timeout);
      // 往返耗时只计算到收到响应头，与真实 TCP / ICMP 的 RTT 一致 / The round trip
      // ends when the response headers arrive, matching a real TCP / ICMP RTT.
      stopwatch.stop();
      // 响应体必须**同步排空**再返回：若交给 `unawaited`，调用方的
      // `client.close()` 会与它抢跑并抛出未捕获的异步错误 / The body must be
      // drained before returning; handing it to `unawaited` races with the
      // caller's `client.close()` and surfaces an uncaught async error.
      await response.stream.drain<void>().timeout(timeout);
      if (response.statusCode >= 400) return null;
      return stopwatch.elapsedMicroseconds / 1000;
    } catch (_) {
      stopwatch.stop();
      return null;
    }
  }

  Future<PingResult> _icmpPing() async {
    throw UnsupportedError(
      'PingMode.icmp is unavailable on the web platform; use PingMode.tcp.',
    );
  }
}
