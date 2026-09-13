// 网络延迟（Ping）测试服务 / Network latency (ping) test service.
//
// 依据平台条件导出实现：原生平台使用 `dart:io`（TCP/ICMP）版本，Web 使用基于
// HTTPS 往返的退化版本 / Conditionally exports the implementation: the native
// build uses the `dart:io` (TCP/ICMP) variant, while the web build uses the
// HTTPS round-trip fallback.
export 'ping_service_io.dart' if (dart.library.html) 'ping_service_web.dart';
