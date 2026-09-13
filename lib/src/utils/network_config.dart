/// 全局默认诊断参数 / Global default parameters used by the diagnostic APIs.
///
/// 所有字段都有合理默认值，可按需覆盖后通过 `ZeroNetworkKit.init(config: ...)`
/// 全局生效。/ Every field has a sensible default; override as needed and apply
/// globally through `ZeroNetworkKit.init(config: ...)`.
class NetworkDiagnosticConfig {
  /// 构造 [NetworkDiagnosticConfig] / Creates a [NetworkDiagnosticConfig].
  const NetworkDiagnosticConfig({
    this.pingHost = '1.1.1.1',
    this.pingPort = 443,
    this.pingCount = 4,
    this.pingTimeout = const Duration(seconds: 3),
    this.pingInterval = const Duration(milliseconds: 200),
    this.dnsDomain = 'www.google.com',
    this.dnsServers = const <String>['1.1.1.1', '8.8.8.8', '114.114.114.114'],
    this.dnsTimeout = const Duration(seconds: 5),
    this.downloadUrl = 'https://speed.cloudflare.com/__down?bytes=25000000',
    this.uploadUrl = 'https://speed.cloudflare.com/__up',
    this.uploadPayloadBytes = 1048576,
    this.speedTestTimeout = const Duration(seconds: 30),
    this.speedTestMaxDuration = const Duration(seconds: 10),
    this.portCheckTimeout = const Duration(seconds: 3),
    this.probePorts = const <int>[80, 443],
    this.qualityTargets = const QualityTargets(),
  });

  /// 默认 Ping 目标主机 / Default ping target host.
  final String pingHost;

  /// 默认 Ping 目标端口（TCP 模式）/ Default ping target port (TCP mode).
  final int pingPort;

  /// 默认 Ping 探测次数 / Default number of ping probes.
  final int pingCount;

  /// 单次 Ping 探测超时 / Timeout of a single ping probe.
  final Duration pingTimeout;

  /// Ping 探测间隔 / Delay between two ping probes.
  final Duration pingInterval;

  /// 默认 DNS 测试域名 / Default domain used for DNS tests.
  final String dnsDomain;

  /// 默认 DNS 服务器列表 / Default DNS servers used for DNS tests.
  final List<String> dnsServers;

  /// 单台 DNS 服务器查询超时 / Timeout of a single DNS query.
  final Duration dnsTimeout;

  /// 默认下载测速地址 / Default download endpoint for the speed test.
  final String downloadUrl;

  /// 默认上传测速地址 / Default upload endpoint for the speed test.
  final String uploadUrl;

  /// 上传测速负载字节数 / Payload size used for the upload speed test.
  final int uploadPayloadBytes;

  /// 测速单请求超时 / Per-request timeout of the speed test.
  final Duration speedTestTimeout;

  /// 测速单阶段最长采样时长 / Maximum sampling window of one speed test phase.
  final Duration speedTestMaxDuration;

  /// 端口检测超时 / Timeout of a single port check.
  final Duration portCheckTimeout;

  /// 默认端口扫描列表 / Default ports probed by `scanPorts()`.
  final List<int> probePorts;

  /// 质量评分的理想值参考 / Ideal values used by the quality evaluator.
  final QualityTargets qualityTargets;
}

/// 质量评分的理想值参考 / Ideal metric values used when scoring quality.
class QualityTargets {
  /// 构造 [QualityTargets] / Creates a [QualityTargets].
  const QualityTargets({
    this.excellentLatency = 30,
    this.acceptableLatency = 150,
    this.excellentJitter = 5,
    this.acceptableJitter = 40,
    this.acceptablePacketLoss = 5,
    this.excellentDownload = 50,
    this.acceptableDownload = 5,
    this.excellentUpload = 20,
    this.acceptableUpload = 2,
    this.excellentDns = 30,
    this.acceptableDns = 200,
  });

  /// 理想延迟（毫秒）/ Latency considered excellent, in milliseconds.
  final double excellentLatency;

  /// 可接受延迟上限（毫秒）/ Latency still considered acceptable, in ms.
  final double acceptableLatency;

  /// 理想抖动（毫秒）/ Jitter considered excellent, in milliseconds.
  final double excellentJitter;

  /// 可接受抖动上限（毫秒）/ Jitter still considered acceptable, in ms.
  final double acceptableJitter;

  /// 可接受丢包率（百分比）/ Packet loss still considered acceptable, in %.
  final double acceptablePacketLoss;

  /// 理想下载速率（Mbps）/ Download throughput considered excellent, in Mbps.
  final double excellentDownload;

  /// 可接受下载速率下限（Mbps）/ Lowest acceptable download throughput, Mbps.
  final double acceptableDownload;

  /// 理想上传速率（Mbps）/ Upload throughput considered excellent, in Mbps.
  final double excellentUpload;

  /// 可接受上传速率下限（Mbps）/ Lowest acceptable upload throughput, Mbps.
  final double acceptableUpload;

  /// 理想 DNS 解析耗时（毫秒）/ DNS latency considered excellent, milliseconds.
  final double excellentDns;

  /// 可接受 DNS 解析耗时上限（毫秒）/ Highest acceptable DNS latency, ms.
  final double acceptableDns;
}
