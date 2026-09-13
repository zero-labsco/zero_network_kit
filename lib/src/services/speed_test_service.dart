import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/ping_result.dart';
import '../models/speed_test_result.dart';
import 'ping_service.dart';

/// 测速过程中出现的错误 / Error raised during a speed test.
///
/// 取代 `dart:io` 的 `HttpException`，使本服务脱离 `dart:io` 依赖 /
/// Replaces `dart:io`'s `HttpException` so this service no longer depends on
/// `dart:io`.
class SpeedTestException implements Exception {
  /// 构造 [SpeedTestException] / Creates a [SpeedTestException].
  const SpeedTestException(this.message, {this.uri});

  /// 人类可读的错误描述 / Human-readable description.
  final String message;

  /// 关联的请求地址（如有）/ The related request URI, if any.
  final Uri? uri;

  @override
  String toString() => uri == null
      ? 'SpeedTestException: $message'
      : 'SpeedTestException: $message ($uri)';
}

/// 测速阶段 / Phase of a speed test run.
enum SpeedTestPhase {
  /// 下载阶段 / Measuring download throughput.
  download,

  /// 上传阶段 / Measuring upload throughput.
  upload,

  /// 全部完成 / All phases finished.
  completed,
}

/// 测速过程中的进度快照 / Progress snapshot emitted during a speed test.
class SpeedTestProgress {
  /// 构造 [SpeedTestProgress] / Creates a [SpeedTestProgress].
  const SpeedTestProgress({
    required this.phase,
    required this.bytes,
    required this.elapsed,
    required this.speedMbps,
  });

  /// 当前阶段 / Current phase.
  final SpeedTestPhase phase;

  /// 当前阶段累计字节数 / Bytes transferred during the current phase.
  final int bytes;

  /// 当前阶段已耗时 / Elapsed time of the current phase.
  final Duration elapsed;

  /// 当前阶段瞬时速率，单位 Mbps / Instantaneous throughput, in Mbps.
  final double speedMbps;

  @override
  String toString() =>
      'SpeedTestProgress(${phase.name}, $bytes bytes, '
      '${speedMbps.toStringAsFixed(2)}Mbps)';
}

/// 带宽（网速）测试服务 / Bandwidth (speed) test service.
class SpeedTestService {
  /// 构造 [SpeedTestService] / Creates a [SpeedTestService].
  ///
  /// 传入 [client] 时复用调用方的 HTTP 客户端且**不会**关闭它；为 `null` 时每次
  /// 测速内部创建并在结束时关闭客户端 / When [client] is provided it is reused
  /// and never closed; otherwise a client is created per run and closed at the
  /// end.
  const SpeedTestService({http.Client? client, PingService? pingService})
    : _client = client,
      _pingService = pingService ?? const PingService();

  final http.Client? _client;
  final PingService _pingService;

  /// 执行一次网速测试 / Runs a complete speed test.
  ///
  /// [downloadUrl] / [uploadUrl] 覆盖默认的测速端点；
  /// [maxDuration] 限制单个阶段的采样时长；[uploadPayloadBytes] 控制上传负载大小；
  /// [includePing] 为 `true` 时先做一次延迟测试并写入
  /// [SpeedTestResult.ping] / [downloadUrl] and [uploadUrl] override the default
  /// endpoints, [maxDuration] caps the sampling window of each phase,
  /// [uploadPayloadBytes] sets the upload payload size, and [includePing]
  /// prefixes the run with a latency test.
  Future<SpeedTestResult> runSpeedTest({
    String downloadUrl = 'https://speed.cloudflare.com/__down?bytes=25000000',
    String? uploadUrl,
    Duration timeout = const Duration(seconds: 30),
    Duration maxDuration = const Duration(seconds: 10),
    Duration pingTimeout = const Duration(seconds: 3),
    int uploadPayloadBytes = 1048576,
    String? pingHost,
    int pingCount = 4,
    bool includeUpload = true,
    bool includePing = true,
    void Function(SpeedTestProgress progress)? onProgress,
  }) async {
    final client = _client ?? http.Client();
    final downloadUri = Uri.parse(downloadUrl);
    final uploadUri = uploadUrl == null ? null : Uri.parse(uploadUrl);

    PingResult? pingResult;
    if (includePing) {
      pingResult = await _pingService.ping(
        host: pingHost ?? downloadUri.host,
        count: pingCount,
        timeout: pingTimeout,
      );
    }

    try {
      final download = await _measureDownload(
        client,
        downloadUri,
        timeout: timeout,
        maxDuration: maxDuration,
        onProgress: onProgress,
      );

      _TransferOutcome? upload;
      if (includeUpload && uploadUri != null) {
        upload = await _measureUpload(
          client,
          uploadUri,
          payload: _buildPayload(uploadPayloadBytes),
          timeout: timeout,
          onProgress: onProgress,
        );
      }

      onProgress?.call(
        const SpeedTestProgress(
          phase: SpeedTestPhase.completed,
          bytes: 0,
          elapsed: Duration.zero,
          speedMbps: 0,
        ),
      );

      return SpeedTestResult(
        downloadSpeed: SpeedTestResult.mbpsFromBytes(
          download.bytes,
          download.elapsed,
        ),
        uploadSpeed: upload == null
            ? 0
            : SpeedTestResult.mbpsFromBytes(upload.bytes, upload.elapsed),
        ping: pingResult?.averageTime ?? 0,
        jitter: pingResult?.jitter ?? 0,
        packetLoss: pingResult?.packetLoss ?? 0,
        downloadedBytes: download.bytes,
        uploadedBytes: upload?.bytes ?? 0,
        downloadDuration: download.elapsed,
        uploadDuration: upload?.elapsed ?? Duration.zero,
        server: downloadUri.host,
        timestamp: DateTime.now(),
      );
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<_TransferOutcome> _measureDownload(
    http.Client client,
    Uri uri, {
    required Duration timeout,
    required Duration maxDuration,
    void Function(SpeedTestProgress progress)? onProgress,
  }) async {
    final request = http.Request('GET', uri)
      ..headers['Cache-Control'] = 'no-cache'
      ..headers['User-Agent'] = 'zero_network_kit/1.0';

    final stopwatch = Stopwatch()..start();
    final response = await client.send(request).timeout(timeout);
    if (response.statusCode >= 400) {
      throw SpeedTestException(
        'Download endpoint returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    var bytes = 0;
    final completer = Completer<void>();
    late StreamSubscription<List<int>> subscription;

    void report() {
      onProgress?.call(
        SpeedTestProgress(
          phase: SpeedTestPhase.download,
          bytes: bytes,
          elapsed: stopwatch.elapsed,
          speedMbps: SpeedTestResult.mbpsFromBytes(bytes, stopwatch.elapsed),
        ),
      );
    }

    subscription = response.stream.listen(
      (chunk) {
        bytes += chunk.length;
        report();
        if (stopwatch.elapsed >= maxDuration) {
          unawaited(subscription.cancel());
          if (!completer.isCompleted) completer.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    await completer.future.timeout(
      timeout,
      onTimeout: () {
        unawaited(subscription.cancel());
      },
    );
    stopwatch.stop();
    return _TransferOutcome(bytes: bytes, elapsed: stopwatch.elapsed);
  }

  Future<_TransferOutcome> _measureUpload(
    http.Client client,
    Uri uri, {
    required Uint8List payload,
    required Duration timeout,
    void Function(SpeedTestProgress progress)? onProgress,
  }) async {
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/octet-stream'
      ..headers['Cache-Control'] = 'no-cache'
      ..headers['User-Agent'] = 'zero_network_kit/1.0'
      ..bodyBytes = payload;

    final stopwatch = Stopwatch()..start();
    final response = await client.send(request).timeout(timeout);
    onProgress?.call(
      SpeedTestProgress(
        phase: SpeedTestPhase.upload,
        bytes: payload.length,
        elapsed: stopwatch.elapsed,
        speedMbps: SpeedTestResult.mbpsFromBytes(
          payload.length,
          stopwatch.elapsed,
        ),
      ),
    );
    await response.stream.drain<void>().timeout(timeout);
    stopwatch.stop();

    if (response.statusCode >= 400) {
      throw SpeedTestException(
        'Upload endpoint returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    return _TransferOutcome(bytes: payload.length, elapsed: stopwatch.elapsed);
  }

  /// 生成不可压缩的随机负载 / Builds an incompressible random payload.
  static Uint8List _buildPayload(int size) {
    final safeSize = math.max(1, size);
    final random = math.Random(1337);
    final payload = Uint8List(safeSize);
    for (var i = 0; i < safeSize; i++) {
      payload[i] = random.nextInt(256);
    }
    return payload;
  }
}

/// 单阶段传输结果 / Outcome of a single transfer phase.
class _TransferOutcome {
  const _TransferOutcome({required this.bytes, required this.elapsed});

  final int bytes;
  final Duration elapsed;
}
