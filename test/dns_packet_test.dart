import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_network_kit/advanced.dart';

Uint8List _responseWithAddress({
  required int id,
  required String domain,
  required List<int> address,
  int recordType = DnsRecordType.a,
  int responseCode = 0,
  bool compression = true,
}) {
  final builder = BytesBuilder(copy: false);
  final header = ByteData(12)
    ..setUint16(0, id)
    ..setUint16(2, 0x8180 | responseCode)
    ..setUint16(4, 1)
    ..setUint16(6, 1);
  builder.add(header.buffer.asUint8List());

  for (final label in domain.split('.')) {
    builder.addByte(label.length);
    builder.add(label.codeUnits);
  }
  builder.addByte(0);
  final question = ByteData(4)
    ..setUint16(0, DnsRecordType.a)
    ..setUint16(2, 1);
  builder.add(question.buffer.asUint8List());

  if (compression) {
    builder.addByte(0xC0);
    builder.addByte(0x0C);
  } else {
    for (final label in domain.split('.')) {
      builder.addByte(label.length);
      builder.add(label.codeUnits);
    }
    builder.addByte(0);
  }

  final record = ByteData(10)
    ..setUint16(0, recordType)
    ..setUint16(2, 1)
    ..setUint32(4, 300)
    ..setUint16(8, address.length);
  builder.add(record.buffer.asUint8List());
  builder.add(address);

  return builder.toBytes();
}

void main() {
  group('DnsPacket.encodeQuery', () {
    test('encodes a well formed A-record query', () {
      final packet = DnsPacket.encodeQuery('example.com', id: 0x1234);

      // 12 字节头部 + 每段域名 + 结束标签 + 4 字节 question。
      expect(packet.length, 12 + 1 + 7 + 1 + 3 + 1 + 4);
      final header = ByteData.sublistView(packet, 0, 12);
      expect(header.getUint16(0), 0x1234);
      expect(header.getUint16(2), 0x0100, reason: 'RD flag set');
      expect(header.getUint16(4), 1, reason: 'single question');
      expect(header.getUint16(6), 0, reason: 'no answers in a query');
    });

    test('rejects labels longer than 63 bytes', () {
      expect(
        () => DnsPacket.encodeQuery('${'a' * 64}.com', id: 1),
        throwsArgumentError,
      );
    });
  });

  group('DnsPacket.parse', () {
    test('parses an A record with a compression pointer', () {
      final data = _responseWithAddress(
        id: 0xABCD,
        domain: 'example.com',
        address: <int>[93, 184, 216, 34],
      );

      final response = DnsPacket.parse(data);

      expect(response.id, 0xABCD);
      expect(response.responseCode, 0);
      expect(response.isSuccess, isTrue);
      expect(response.addresses, <String>['93.184.216.34']);
      expect(response.answers.first.name, 'example.com');
      expect(response.answers.first.ttl, 300);
    });

    test('parses a record written without compression', () {
      final data = _responseWithAddress(
        id: 7,
        domain: 'one.one.one.one',
        address: <int>[1, 1, 1, 1],
        compression: false,
      );

      expect(DnsPacket.parse(data).addresses, <String>['1.1.1.1']);
    });

    test('decodes AAAA records into colon notation', () {
      final data = _responseWithAddress(
        id: 9,
        domain: 'ipv6.example',
        address: <int>[
          0x20,
          0x01,
          0x0d,
          0xb8,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          1,
        ],
        recordType: DnsRecordType.aaaa,
      );

      expect(DnsPacket.parse(data).addresses, <String>[
        '2001:0db8:0000:0000:0000:0000:0000:0001',
      ]);
    });

    test('surfaces a non zero response code as failure', () {
      final data = _responseWithAddress(
        id: 11,
        domain: 'missing.example',
        address: <int>[0, 0, 0, 0],
        responseCode: 3,
      );

      final response = DnsPacket.parse(data);
      expect(response.responseCode, 3);
      expect(response.isSuccess, isFalse);
    });

    test('throws on a truncated header', () {
      expect(
        () => DnsPacket.parse(Uint8List.fromList(<int>[0, 1, 2])),
        throwsFormatException,
      );
    });

    test('throws on a compression loop', () {
      final bytes = Uint8List.fromList(<int>[
        0, 1, 0x81, 0x80, 0, 1, 0, 0, 0, 0, 0, 0, // header
        0xC0, 0x0C, // pointer back to itself
        0, 1, 0, 1,
      ]);

      expect(() => DnsPacket.parse(bytes), throwsFormatException);
    });
  });

  test('randomId stays inside the 16-bit range', () {
    for (var i = 0; i < 200; i++) {
      final id = DnsPacket.randomId();
      expect(id, inInclusiveRange(0, 0xFFFF));
    }
  });
}
