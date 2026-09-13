// TCP 端口连通性检测服务 / TCP port reachability service.
//
// 依据平台条件导出实现：原生平台使用 `dart:io`（原始 TCP 套接字）版本，Web 上
// 端口检测不可用，导出返回“不可用”结果的退化版本 /
// Conditionally exports the implementation: the native build uses the `dart:io`
// (raw TCP socket) variant, while the web build exports the variant that reports
// port checks as unavailable.
export 'port_service_io.dart' if (dart.library.html) 'port_service_web.dart';
