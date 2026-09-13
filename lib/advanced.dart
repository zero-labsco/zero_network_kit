/// 进阶 / 注入 / 底层 API / Advanced, injectable and low-level APIs.
///
/// 日常使用请优先 `package:zero_network_kit`；本文件面向需要自定义服务实现、
/// 注入假实现或访问底层 DNS 报文编解码器的场景 /
/// Prefer `package:zero_network_kit` for everyday use; import this file when you
/// need to supply custom service implementations, inject fakes, or access the
/// low-level DNS codec.
library;

export 'src/services/connectivity_service.dart';
export 'src/services/ping_service.dart';
export 'src/services/dns_service.dart';
export 'src/services/port_service.dart';
export 'src/services/speed_test_service.dart';
export 'src/services/quality_service.dart';
export 'src/services/quality_evaluator.dart';
export 'src/services/benchmark_service.dart';
export 'src/dns/dns_packet.dart';
