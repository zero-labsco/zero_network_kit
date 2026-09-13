import 'dart:async';
import 'dart:io';

import '../dns/dns_packet.dart';
import '../models/dns_test_result.dart';

/// DNS 解析测试服务 / DNS resolution test service.
///
/// 支持两种解析路径 / Two resolution paths are supported:
/// - 系统解析器（`InternetAddress.lookup`）/ the platform resolver;
/// - 指定 DNS 服务器的原始 UDP 查询（自实现报文编解码）/
///   raw UDP queries against explicit DNS servers, using the built-in codec.
class DnsService {
  /// 构造 [DnsService] / Creates a [DnsService].
  const DnsService({this.defaultTimeout = const Duration(seconds: 5)});

  /// 单次查询默认超时 / Default timeout of a single query.
  final Duration defaultTimeout;

  /// 依次/并发测试多台 DNS 服务器 / Tests multiple DNS servers.
  ///
  /// [concurrent] 为 `true`（默认）时并发查询；为 `false` 时按顺序查询，可用于
  /// 规避部分网络对并发 UDP 的限制 / [concurrent] queries in parallel by
  /// default; set it to `false` to serialise them.
  /// [includeSystemResolver] 为 `true` 时额外加入一条系统解析器结果 /
  /// [includeSystemResolver] also appends a platform-resolver result.
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
  ///
  /// [server] 传 `system` 时走系统解析器 / Pass `system` as [server] to use the
  /// platform resolver.
  Future<DnsTestResult> query({
    required String domain,
    required String server,
    Duration? timeout,
  }) {
    if (server.toLowerCase() == 'system') {
      return resolveWithSystemResolver(domain: domain, timeout: timeout);
    }
    return _queryUdp(
      domain: domain,
      server: server,
      timeout: timeout ?? defaultTimeout,
    );
  }

  /// 使用系统解析器解析域名 / Resolves a domain through the platform resolver.
  Future<DnsTestResult> resolveWithSystemResolver({
    required String domain,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final addresses = await InternetAddress.lookup(
        domain,
      ).timeout(timeout ?? defaultTimeout);
      stopwatch.stop();
      return DnsTestResult(
        server: 'system',
        domain: domain,
        isSuccess: addresses.isNotEmpty,
        responseTime: stopwatch.elapsed,
        resolvedIps: addresses
            .map((address) => address.address)
            .toList(growable: false),
        timestamp: DateTime.now(),
        errorMessage: addresses.isEmpty ? 'No address returned' : null,
      );
    } catch (error) {
      stopwatch.stop();
      return DnsTestResult(
        server: 'system',
        domain: domain,
        isSuccess: false,
        responseTime: stopwatch.elapsed,
        errorMessage: error.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  Future<DnsTestResult> _queryUdp({
    required String domain,
    required String server,
    required Duration timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;
    Timer? timer;

    try {
      final target = await _resolveServer(server).timeout(timeout);
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final udp = socket;
      final id = DnsPacket.randomId();
      final payload = DnsPacket.encodeQuery(domain, id: id);
      final completer = Completer<DnsResponse>();

      subscription = udp.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          final datagram = udp.receive();
          if (datagram == null) return;
          try {
            final response = DnsPacket.parse(datagram.data);
            if (response.id != id) return;
            if (!completer.isCompleted) completer.complete(response);
          } catch (error) {
            if (!completer.isCompleted) completer.completeError(error);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      );

      timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException('DNS query to $server timed out', timeout),
          );
        }
      });

      udp.send(payload, target, 53);

      final response = await completer.future.timeout(
        timeout,
        onTimeout: () =>
            throw TimeoutException('DNS query to $server timed out', timeout),
      );
      stopwatch.stop();

      if (response.responseCode != 0) {
        return DnsTestResult(
          server: server,
          domain: domain,
          isSuccess: false,
          responseTime: stopwatch.elapsed,
          errorMessage: 'DNS server returned RCODE ${response.responseCode}',
          timestamp: DateTime.now(),
        );
      }

      return DnsTestResult(
        server: server,
        domain: domain,
        isSuccess: response.isSuccess,
        responseTime: stopwatch.elapsed,
        resolvedIps: response.addresses,
        timestamp: DateTime.now(),
        errorMessage: response.isSuccess
            ? null
            : (response.truncated
                  ? 'Response truncated; retry over TCP'
                  : 'No A/AAAA record in the answer section'),
      );
    } catch (error) {
      stopwatch.stop();
      return DnsTestResult(
        server: server,
        domain: domain,
        isSuccess: false,
        responseTime: stopwatch.elapsed,
        errorMessage: error.toString(),
        timestamp: DateTime.now(),
      );
    } finally {
      timer?.cancel();
      await subscription?.cancel();
      socket?.close();
    }
  }

  static Future<InternetAddress> _resolveServer(String server) async {
    final parsed = InternetAddress.tryParse(server);
    if (parsed != null) return parsed;
    final addresses = await InternetAddress.lookup(server);
    if (addresses.isEmpty) {
      throw SocketException('Cannot resolve DNS server: $server');
    }
    return addresses.first;
  }
}
