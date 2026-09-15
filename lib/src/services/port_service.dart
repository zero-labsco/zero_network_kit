// TCP 端口连通性检测服务 / TCP port reachability service.
//
// 依据平台条件导出实现：默认导出不含 `dart:io` 的 Web 版本（端口检测不可用），
// 仅在 `dart:io` 可用时改为原生版本 / Conditionally exports the implementation:
// the `dart:io`-free web variant (port checks unavailable) is the default, and
// the native `dart:io` (raw TCP socket) variant is selected only when `dart:io`
// is available.
export 'port_service_web.dart' if (dart.library.io) 'port_service_io.dart';
