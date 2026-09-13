import 'dart:math' as math;
import 'dart:typed_data';

/// DNS 资源记录类型 / DNS resource record types understood by this codec.
class DnsRecordType {
  /// A 记录（IPv4）/ A record (IPv4).
  static const int a = 1;

  /// CNAME 记录 / Canonical name record.
  static const int cname = 5;

  /// AAAA 记录（IPv6）/ AAAA record (IPv6).
  static const int aaaa = 28;
}

/// 单条 DNS 应答记录 / A single DNS answer record.
class DnsAnswer {
  /// 构造 [DnsAnswer] / Creates a [DnsAnswer].
  const DnsAnswer({
    required this.name,
    required this.type,
    required this.ttl,
    required this.value,
  });

  /// 记录所属域名 / Owner name of the record.
  final String name;

  /// 记录类型，见 [DnsRecordType] / Record type, see [DnsRecordType].
  final int type;

  /// 生存时间，单位秒 / Time to live in seconds.
  final int ttl;

  /// 记录值（A/AAAA 为地址字符串，CNAME 为目标域名）/
  /// Record value: an address string for A/AAAA, a domain for CNAME.
  final String value;

  @override
  String toString() => 'DnsAnswer($name, type: $type, ttl: $ttl, $value)';
}

/// 解析后的 DNS 响应 / A parsed DNS response message.
class DnsResponse {
  /// 构造 [DnsResponse] / Creates a [DnsResponse].
  const DnsResponse({
    required this.id,
    required this.responseCode,
    required this.answers,
    this.truncated = false,
  });

  /// 事务 ID / Transaction id echoed from the query.
  final int id;

  /// 响应码，0 表示成功 / Response code, 0 means success.
  final int responseCode;

  /// 应答记录列表 / Answer records.
  final List<DnsAnswer> answers;

  /// 是否被截断 / Whether the response was truncated.
  final bool truncated;

  /// 是否解析成功 / Whether the server answered successfully.
  bool get isSuccess => responseCode == 0 && answers.isNotEmpty;

  /// A / AAAA 记录中的地址列表 / Address values extracted from A and AAAA records.
  List<String> get addresses => answers
      .where(
        (answer) =>
            answer.type == DnsRecordType.a || answer.type == DnsRecordType.aaaa,
      )
      .map((answer) => answer.value)
      .toList(growable: false);

  @override
  String toString() =>
      'DnsResponse(id: $id, rcode: $responseCode, answers: $answers)';
}

/// 极简 DNS 报文编解码器 / A minimal DNS wire-format codec.
///
/// 只覆盖诊断场景需要的部分：构造标准的 A 记录查询，解析响应头与应答段
/// （支持名称压缩指针、A / AAAA / CNAME 记录）/
/// Covers only what diagnostics need: building a standard A-record query and
/// parsing the header plus the answer section, including name compression
/// pointers and A / AAAA / CNAME records.
class DnsPacket {
  const DnsPacket._();

  /// 构造一个 A 记录查询报文 / Builds a standard A-record query message.
  static Uint8List encodeQuery(String domain, {required int id}) {
    final labels = domain
        .split('.')
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    final safeLabels = labels.isEmpty ? const <String>['localhost'] : labels;

    final builder = BytesBuilder(copy: false);
    final header = ByteData(12);
    header.setUint16(0, id & 0xFFFF);
    header.setUint16(2, 0x0100); // RD = 1 / recursion desired.
    header.setUint16(4, 1); // QDCOUNT
    header.setUint16(6, 0); // ANCOUNT
    header.setUint16(8, 0); // NSCOUNT
    header.setUint16(10, 0); // ARCOUNT
    builder.add(header.buffer.asUint8List());

    for (final label in safeLabels) {
      final bytes = Uint8List.fromList(label.codeUnits);
      if (bytes.length > 63) {
        throw ArgumentError.value(
          label,
          'domain',
          'DNS label exceeds 63 bytes',
        );
      }
      builder.addByte(bytes.length);
      builder.add(bytes);
    }
    builder.addByte(0); // Root label.

    final question = ByteData(4);
    question.setUint16(0, DnsRecordType.a);
    question.setUint16(2, 1); // IN class.
    builder.add(question.buffer.asUint8List());

    return builder.toBytes();
  }

  /// 解析 DNS 响应报文 / Parses a DNS response message.
  ///
  /// 报文不合法时抛出 [FormatException] / Throws [FormatException] when the
  /// message is malformed.
  static DnsResponse parse(Uint8List data) {
    if (data.length < 12) {
      throw const FormatException(
        'DNS message shorter than the 12-byte header',
      );
    }
    final header = ByteData.sublistView(data, 0, 12);
    final id = header.getUint16(0);
    final flags = header.getUint16(2);
    final responseCode = flags & 0x000F;
    final truncated = (flags & 0x0200) != 0;
    final questionCount = header.getUint16(4);
    final answerCount = header.getUint16(6);

    var offset = 12;
    for (var i = 0; i < questionCount; i++) {
      offset = _skipName(data, offset);
      if (offset + 4 > data.length) {
        throw const FormatException('Truncated DNS question section');
      }
      offset += 4; // QTYPE + QCLASS.
    }

    final answers = <DnsAnswer>[];
    for (var i = 0; i < answerCount; i++) {
      final name = _readName(data, offset);
      offset = name.nextOffset;
      if (offset + 10 > data.length) {
        throw const FormatException('Truncated DNS answer section');
      }
      final record = ByteData.sublistView(data, offset, offset + 10);
      final type = record.getUint16(0);
      final ttl = record.getUint32(4);
      final length = record.getUint16(8);
      offset += 10;
      if (offset + length > data.length) {
        throw const FormatException('DNS record payload exceeds message size');
      }

      final value = _readRecordValue(data, offset, length, type);
      if (value != null) {
        answers.add(
          DnsAnswer(name: name.value, type: type, ttl: ttl, value: value),
        );
      }
      offset += length;
    }

    return DnsResponse(
      id: id,
      responseCode: responseCode,
      answers: answers,
      truncated: truncated,
    );
  }

  static String? _readRecordValue(
    Uint8List data,
    int offset,
    int length,
    int type,
  ) {
    switch (type) {
      case DnsRecordType.a:
        if (length != 4) return null;
        return '${data[offset]}.${data[offset + 1]}.'
            '${data[offset + 2]}.${data[offset + 3]}';
      case DnsRecordType.aaaa:
        if (length != 16) return null;
        final parts = <String>[];
        for (var i = 0; i < 16; i += 2) {
          parts.add(
            ((data[offset + i] << 8) | data[offset + i + 1])
                .toRadixString(16)
                .padLeft(4, '0'),
          );
        }
        return parts.join(':');
      case DnsRecordType.cname:
        return _readName(data, offset).value;
      default:
        return null;
    }
  }

  static int _skipName(Uint8List data, int offset) =>
      _readName(data, offset).nextOffset;

  /// 读取一个域名，自动跟随压缩指针 / Reads a domain name, following compression
  /// pointers when present.
  static _ParsedName _readName(Uint8List data, int offset) {
    final labels = <String>[];
    var cursor = offset;
    int? endOffset;
    var jumps = 0;

    while (true) {
      if (cursor >= data.length) {
        throw const FormatException(
          'DNS name runs past the end of the message',
        );
      }
      final length = data[cursor];
      if (length == 0) {
        cursor += 1;
        break;
      }
      if ((length & 0xC0) == 0xC0) {
        if (cursor + 1 >= data.length) {
          throw const FormatException('Truncated DNS compression pointer');
        }
        final pointer = ((length & 0x3F) << 8) | data[cursor + 1];
        endOffset ??= cursor + 2;
        jumps += 1;
        if (jumps > 32 || pointer >= data.length) {
          throw const FormatException('Invalid DNS compression pointer');
        }
        cursor = pointer;
        continue;
      }
      if (cursor + 1 + length > data.length) {
        throw const FormatException('Truncated DNS label');
      }
      labels.add(String.fromCharCodes(data, cursor + 1, cursor + 1 + length));
      cursor += 1 + length;
    }

    return _ParsedName(
      labels.isEmpty ? '.' : labels.join('.'),
      endOffset ?? cursor,
    );
  }

  /// 生成一个随机的 DNS 事务 ID / Generates a random DNS transaction id.
  static int randomId([math.Random? random]) =>
      (random ?? math.Random()).nextInt(0xFFFF);
}

/// 域名解析的中间结果 / Intermediate result while decoding a domain name.
class _ParsedName {
  const _ParsedName(this.value, this.nextOffset);

  final String value;
  final int nextOffset;
}
