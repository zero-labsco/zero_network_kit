import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_network_kit/advanced.dart';

void main() {
  group('SpeedTestService', () {
    test('measures positive download and upload throughput', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((request) async {
        if (request.method == 'POST') {
          // 丢弃上传体 / Discard the upload body.
          await request.drain<void>();
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.text;
          request.response.write('ok');
          await request.response.close();
          return;
        }
        // GET：返回一段固定大小的可下载数据 / A fixed-size download payload.
        const body = 'zero_network_kit_speed_test\n';
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.text;
        request.response.add(utf8.encode(body * 1000));
        await request.response.close();
      });

      final base =
          'http://${InternetAddress.loopbackIPv4.address}:${server.port}';
      final result = await const SpeedTestService().runSpeedTest(
        downloadUrl: '$base/',
        uploadUrl: '$base/',
        uploadPayloadBytes: 65536,
        timeout: const Duration(seconds: 10),
        maxDuration: const Duration(milliseconds: 500),
        includePing: false,
      );

      expect(result.downloadedBytes, greaterThan(0));
      expect(result.downloadSpeed, greaterThan(0));
      expect(result.uploadedBytes, 65536);
      expect(result.uploadSpeed, greaterThan(0));
      // 上传耗时应当只反映「请求体发出」，而非包含服务器回包下载 /
      // The upload duration should reflect the request send only, not the drain.
      expect(result.uploadDuration, greaterThan(Duration.zero));
    });
  });
}
