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
    try {
      // URI 解析与延迟探测都必须包在 `try` 内：否则它们抛异常时 `finally` 不会
      // 执行，内部创建的客户端就泄漏了 / URI parsing and the latency probe must
      // live inside `try`; otherwise an exception skips `finally` and the
      // internally created client leaks.
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
    // 刻意不发送 `Cache-Control`：它不属于 CORS 安全头（白名单只有 Accept /
    // Accept-Language / Content-Language / Content-Type / Range），设置后浏览器会
    // 先发 OPTIONS 预检，而多数测速端点只放行 `authorization, content-type`，
    // 预检被拒即表现为 Web 上的 `Failed to fetch`。测速端点自身已下发
    // `Cache-Control: no-store` /
    // `Cache-Control` is intentionally omitted: it is not CORS-safelisted, so
    // setting it forces an OPTIONS preflight that most speed-test endpoints
    // reject, surfacing as `Failed to fetch` on the web. Endpoints already
    // send `Cache-Control: no-store` themselves.
    final request = http.Request('GET', uri)
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
    // 同样省略 `Cache-Control`，理由见 [_measureDownload] /
    // `Cache-Control` is omitted here too; see [_measureDownload] for why.
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/octet-stream'
      ..headers['User-Agent'] = 'zero_network_kit/1.0'
      ..bodyBytes = payload;

    final stopwatch = Stopwatch()..start();
    final response = await client.send(request).timeout(timeout);
    // 计时止于「收到响应头」：`package:http` 不暴露请求体发完的时刻，因此该值
    // 实际还含服务端处理与首字节回程，是偏保守（偏低）的估计，且不含响应体下载 /
    // Timing stops when the response headers arrive: `package:http` does not
    // expose the moment the body finished sending, so the figure also covers
    // server processing and the first return byte — a conservative (low) estimate
    // that never includes the response body download.
    stopwatch.stop();
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

    if (response.statusCode >= 400) {
      throw SpeedTestException(
        'Upload endpoint returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    return _TransferOutcome(bytes: payload.length, elapsed: stopwatch.elapsed);
  }

  /// 生成不可压缩的随机负载，同尺寸结果会被缓存 /
  /// Builds an incompressible random payload; identical sizes are cached.
  ///
  /// 逐字节生成 1 MiB 负载要跑一百万次循环，每次测速都重算纯属浪费；种子固定为
  /// 1337，因此同一尺寸的负载内容始终一致，缓存是安全的 / Filling a 1 MiB payload
  /// byte by byte costs a million iterations, and redoing it on every run is
  /// pure waste; the seed is fixed at 1337, so the bytes for a given size are
  /// always identical and caching is safe.
  static Uint8List _buildPayload(int size) {
    final safeSize = math.max(1, size);
    final cached = _payloadCache;
    if (cached != null && _payloadCacheSize == safeSize) return cached;

    final random = math.Random(1337);
    final payload = Uint8List(safeSize);
    for (var i = 0; i < safeSize; i++) {
      payload[i] = random.nextInt(256);
    }
    _payloadCache = payload;
    _payloadCacheSize = safeSize;
    return payload;
  }

  static Uint8List? _payloadCache;
  static int _payloadCacheSize = 0;
}

/// 单阶段传输结果 / Outcome of a single transfer phase.
class _TransferOutcome {
  const _TransferOutcome({required this.bytes, required this.elapsed});

  final int bytes;
  final Duration elapsed;
}
