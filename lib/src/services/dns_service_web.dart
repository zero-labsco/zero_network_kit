import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dns_test_result.dart';

/// Web 端 DNS 解析测试服务 / DNS resolution service for the web platform.
///
/// 浏览器禁止原始 UDP 套接字，因此：
/// - 系统解析器退化为通过 DNS-over-HTTPS (DoH) 解析；
/// - 显式 DNS 服务器若提供已知 DoH 端点（如 1.1.1.1 / 8.8.8.8）则走 DoH，
///   否则（如 114.114.114.114）返回“不支持”结果 /
/// Browsers forbid raw UDP sockets, so on the web:
/// - the platform resolver degrades to DNS-over-HTTPS (DoH);
/// - explicit servers with a known DoH endpoint (e.g. 1.1.1.1 / 8.8.8.8) use DoH,
///   while others (e.g. 114.114.114.114) report "unsupported".
class DnsService {
  /// 构造 [DnsService] / Creates a [DnsService].
  const DnsService({this.defaultTimeout = const Duration(seconds: 5)});

  /// 单次查询默认超时 / Default timeout of a single query.
  final Duration defaultTimeout;

  /// 依次/并发测试多台 DNS 服务器 / Tests multiple DNS servers.
  Future<List<DnsTestResult>> testDns({
    String domain = 'www.google.com',
    List<String> dnsServers = const <String>[
      '1.1.1.1',
      '8.8.8.8',
      '114.114.114.114',
    ],
    Duration? timeout,
    bool concurrent = true,
    bool includeSystemResolver = false,
  }) async {
    final servers = <String>[
      if (includeSystemResolver) 'system',
      ...dnsServers,
    ];
    if (servers.isEmpty) return const <DnsTestResult>[];

    if (concurrent) {
      return Future.wait(
        servers.map(
          (server) => query(domain: domain, server: server, timeout: timeout),
        ),
      );
    }

    final results = <DnsTestResult>[];
    for (final server in servers) {
      results.add(
        await query(domain: domain, server: server, timeout: timeout),
      );
    }
    return results;
  }

  /// 查询单个 DNS 服务器 / Queries a single DNS server.
  Future<DnsTestResult> query({
    required String domain,
    required String server,
    Duration? timeout,
  }) {
    if (server.toLowerCase() == 'system') {
      return resolveWithSystemResolver(domain: domain, timeout: timeout);
    }
    final doh = _dohForServer(server);
    if (doh == null) {
      return Future<DnsTestResult>.value(
        DnsTestResult(
          server: server,
          domain: domain,
          isSuccess: false,
          responseTime: Duration.zero,
          errorMessage:
              'Raw UDP DNS is unavailable on the web; this server has no DoH '
              'endpoint.',
          timestamp: DateTime.now(),
        ),
      );
    }
    return _queryDoH(
      domain: domain,
      dohUrl: doh,
      timeout: timeout ?? defaultTimeout,
      serverLabel: server,
    );
  }

  /// 使用系统解析器解析域名（Web 端通过 DoH 实现）/
  /// Resolves a domain through the platform resolver (DoH on the web).
  Future<DnsTestResult> resolveWithSystemResolver({
    required String domain,
    Duration? timeout,
  }) {
    return _queryDoH(
      domain: domain,
      dohUrl: 'https://cloudflare-dns.com/dns-query',
      timeout: timeout ?? defaultTimeout,
      serverLabel: 'system',
    );
  }

  /// 将知名 DNS 服务器映射到其 DoH 端点 / Maps well-known DNS servers to DoH.
  static String? _dohForServer(String server) {
    switch (server) {
      case '1.1.1.1':
      case '1.0.0.1':
        return 'https://cloudflare-dns.com/dns-query';
      case '8.8.8.8':
      case '8.8.4.4':
        return 'https://dns.google/dns-query';
      default:
        return 'https://$server/dns-query';
    }
  }

  /// 通过 DNS-over-HTTPS (JSON) 查询域名 / Resolves a domain over DoH (JSON).
  Future<DnsTestResult> _queryDoH({
    required String domain,
    required String dohUrl,
    required Duration timeout,
    required String serverLabel,
  }) async {
    final stopwatch = Stopwatch()..start();
    final client = http.Client();
    try {
      final response = await client
          .get(
            Uri.parse('$dohUrl?name=$domain&type=A'),
            headers: <String, String>{'Accept': 'application/dns-json'},
          )
          .timeout(timeout);
      stopwatch.stop();
      if (response.statusCode != 200) {
        return DnsTestResult(
          server: serverLabel,
          domain: domain,
          isSuccess: false,
          responseTime: stopwatch.elapsed,
          errorMessage: 'DoH returned HTTP ${response.statusCode}',
          timestamp: DateTime.now(),
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final answers =
          (json['Answer'] as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];
      final ips = answers
          .where((answer) => answer['type'] == 1 || answer['type'] == 28)
          .map((answer) => answer['data'].toString())
          .toList(growable: false);
      return DnsTestResult(
        server: serverLabel,
        domain: domain,
        isSuccess: ips.isNotEmpty,
        responseTime: stopwatch.elapsed,
        resolvedIps: ips,
        timestamp: DateTime.now(),
        errorMessage: ips.isEmpty ? 'No A/AAAA record returned' : null,
      );
    } catch (error) {
      stopwatch.stop();
      return DnsTestResult(
        server: serverLabel,
        domain: domain,
        isSuccess: false,
        responseTime: stopwatch.elapsed,
        errorMessage: error.toString(),
        timestamp: DateTime.now(),
      );
    } finally {
      client.close();
    }
  }
}
