import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import '../models/ping_result.dart';

/// 网络延迟（Ping）测试服务 / Network latency (ping) test service.
///
/// 默认使用 TCP 握手往返测量，跨平台且无需特殊权限；桌面端可选择使用系统
/// ICMP `ping` 命令 / TCP handshake timing is used by default: it works on every
/// platform without extra privileges. Desktop platforms may opt into the system
/// ICMP `ping` command instead.
class PingService {
  /// 构造 [PingService] / Creates a [PingService].
  const PingService({this.defaultPort = 443});

  /// TCP 模式下默认探测端口 / Default probe port in TCP mode.
  final int defaultPort;

  /// 执行 Ping 测试 / Runs a ping test.
  ///
  /// [count] 为探测次数，[interval] 为两次探测之间的间隔 /
  /// [count] is the number of probes, [interval] the delay between them.
  /// [mode] 为 [PingMode.icmp] 时仅桌面端可用，其它平台抛出
  /// [UnsupportedError] / [PingMode.icmp] is desktop-only and throws
  /// [UnsupportedError] elsewhere.
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
      return _icmpPing(host: host, count: count, timeout: timeout);
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
    // 先解析一次目标地址：否则每次探测都会把域名解析耗时计进往返时间，
    // `jitter` 也会被解析缓存的抖动污染 / Resolve the target once; otherwise
    // every probe bills the DNS lookup to the round trip time and pollutes
    // `jitter` with resolver-cache noise.
    final target = await _resolveTarget(host);

    final times = <double>[];
    for (var i = 0; i < count; i++) {
      if (i > 0 && interval > Duration.zero) {
        await Future<void>.delayed(interval);
      }
      final elapsed = await _probeTcp(target, port, timeout);
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

  /// 把主机名解析为 [InternetAddress]，失败时原样返回主机名 /
  /// Resolves [host] to an [InternetAddress], falling back to the raw host.
  static Future<Object> _resolveTarget(String host) async {
    final parsed = InternetAddress.tryParse(host);
    if (parsed != null) return parsed;
    try {
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isNotEmpty) return addresses.first;
    } catch (_) {
      // 解析失败时交回主机名，让 Socket.connect 自己报错 /
      // Hand the raw host back so Socket.connect reports the failure.
    }
    return host;
  }

  static Future<double?> _probeTcp(
    Object host,
    int port,
    Duration timeout,
  ) async {
    final stopwatch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      stopwatch.stop();
      return stopwatch.elapsedMicroseconds / 1000;
    } catch (_) {
      return null;
    } finally {
      socket?.destroy();
    }
  }

  /// 构造系统 `ping` 命令的参数 / Builds the arguments for the system `ping`.
  ///
  /// 三个平台的超时单位**互不相同**，必须分别处理 / The timeout unit differs on
  /// every platform and must be handled separately:
  /// - Windows `-w`：毫秒 / milliseconds;
  /// - macOS (BSD) `-W`：毫秒 / milliseconds;
  /// - Linux (iputils) `-W`：**秒**，且必须 ≥ 1 / **seconds**, and must be ≥ 1.
  ///
  /// macOS 曾误用 Linux 的「秒」语义，导致 `-W 3` 被解释成 3 毫秒、所有探测必然
  /// 超时 / macOS previously reused the Linux "seconds" meaning, so `-W 3` was
  /// read as 3 ms and every probe timed out.
  static List<String> icmpArgs({
    required String host,
    required int count,
    required Duration timeout,
    required bool isWindows,
    required bool isMacOS,
  }) {
    if (isWindows) {
      return <String>['-n', '$count', '-w', '${timeout.inMilliseconds}', host];
    }
    if (isMacOS) {
      return <String>['-c', '$count', '-W', '${timeout.inMilliseconds}', host];
    }
    return <String>[
      '-c',
      '$count',
      '-W',
      '${math.max(1, timeout.inSeconds)}',
      host,
    ];
  }

  Future<PingResult> _icmpPing({
    required String host,
    required int count,
    required Duration timeout,
  }) async {
    if (!_systemPingSupported) {
      throw UnsupportedError(
        'PingMode.icmp requires a desktop platform with a system ping '
        'executable; use PingMode.tcp on mobile.',
      );
    }

    final args = icmpArgs(
      host: host,
      count: count,
      timeout: timeout,
      isWindows: Platform.isWindows,
      isMacOS: Platform.isMacOS,
    );

    final process = await Process.run(
      'ping',
      args,
    ).timeout(timeout * count + const Duration(seconds: 5));
    final output = '${process.stdout}\n${process.stderr}';
    final times = _parseIcmpTimes(output);

    return PingResult(
      host: host,
      sent: count,
      received: times.length,
      times: times,
      timestamp: DateTime.now(),
      mode: PingMode.icmp,
    );
  }

  /// 解析系统 ping 输出中的往返耗时（兼容中英文输出）/
  /// Extracts round trip times from system ping output (English and Chinese).
  static List<double> _parseIcmpTimes(String output) {
    final pattern = RegExp(
      r'(?:time|时间)[=<]\s*([0-9]+(?:\.[0-9]+)?)\s*ms',
      caseSensitive: false,
    );
    return pattern
        .allMatches(output)
        .map((match) => double.tryParse(match.group(1) ?? '') ?? double.nan)
        .where((value) => !value.isNaN)
        .toList(growable: false);
  }

  static bool get _systemPingSupported =>
      !Platform.isAndroid && !Platform.isIOS && !Platform.isFuchsia;
}
