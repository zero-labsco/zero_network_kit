// DNS 解析测试服务 / DNS resolution test service.
//
// 依据平台条件导出实现：原生平台使用 `dart:io`（系统解析器 + 原始 UDP）版本，
// Web 使用基于 DNS-over-HTTPS 的版本 / Conditionally exports the implementation:
// the native build uses the `dart:io` (system resolver + raw UDP) variant, while
// the web build uses the DNS-over-HTTPS variant.
export 'dns_service_io.dart' if (dart.library.html) 'dns_service_web.dart';
