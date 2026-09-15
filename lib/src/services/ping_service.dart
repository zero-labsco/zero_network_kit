// 网络延迟（Ping）测试服务 / Network latency (ping) test service.
//
// 依据平台条件导出实现：默认导出不含 `dart:io` 的 Web 版本，仅在 `dart:io`
// 可用时改为原生版本 / Conditionally exports the implementation: the
// `dart:io`-free web variant is the default, and the native `dart:io` (TCP/ICMP)
// variant is selected only when `dart:io` is available.
export 'ping_service_web.dart' if (dart.library.io) 'ping_service_io.dart';
