// DNS 解析测试服务 / DNS resolution test service.
//
// 依据平台条件导出实现：默认导出不含 `dart:io` 的 Web 版本（DNS-over-HTTPS），
// 仅在 `dart:io` 可用时改为原生版本 / Conditionally exports the implementation:
// the `dart:io`-free web (DNS-over-HTTPS) variant is the default, and the native
// `dart:io` (system resolver + raw UDP) variant is selected only when `dart:io`
// is available.
export 'dns_service_web.dart' if (dart.library.io) 'dns_service_io.dart';
