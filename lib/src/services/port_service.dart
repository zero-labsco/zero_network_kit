import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import '../models/port_check_result.dart';

/// TCP 端口连通性检测服务 / TCP port reachability service.
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
    final effectiveTimeout = timeout ?? defaultTimeout;
    final stopwatch = Stopwatch()..start();
    Socket? socket;

    try {
      socket = await Socket.connect(host, port, timeout: effectiveTimeout);
      stopwatch.stop();
      return PortCheckResult(
        host: host,
        port: port,
        isOpen: true,
        responseTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
      );
    } catch (error) {
      stopwatch.stop();
      return PortCheckResult(
        host: host,
        port: port,
        isOpen: false,
        responseTime: stopwatch.elapsed,
        errorMessage: _describe(error),
        timestamp: DateTime.now(),
      );
    } finally {
      socket?.destroy();
    }
  }

  /// [checkPort] 的布尔快捷方式 / Boolean shorthand for [checkPort].
  Future<bool> isPortOpen({
    required String host,
    required int port,
    Duration? timeout,
  }) async {
    final result = await checkPort(host: host, port: port, timeout: timeout);
    return result.isOpen;
  }

  /// 并发扫描多个端口 / Scans multiple ports with bounded concurrency.
  ///
  /// 结果顺序与 [ports] 一致 / Results preserve the order of [ports].
  Future<List<PortCheckResult>> scanPorts({
    required String host,
    List<int> ports = const <int>[80, 443],
    Duration? timeout,
    int concurrency = 12,
  }) async {
    if (ports.isEmpty) return const <PortCheckResult>[];

    final results = List<PortCheckResult?>.filled(ports.length, null);
    var cursor = 0;

    Future<void> worker() async {
      while (true) {
        final index = cursor;
        cursor += 1;
        if (index >= ports.length) return;
        results[index] = await checkPort(
          host: host,
          port: ports[index],
          timeout: timeout,
        );
      }
    }

    final workerCount = math.min(math.max(1, concurrency), ports.length);
    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    return results.whereType<PortCheckResult>().toList(growable: false);
  }

  static String _describe(Object error) {
    if (error is TimeoutException) return 'Connection timed out';
    if (error is SocketException) {
      return error.osError?.message ?? error.message;
    }
    return error.toString();
  }
}
