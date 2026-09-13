// 连通性检测与网络信息采集服务 / Connectivity detection and network information
// service.
//
// 依据平台条件导出实现：原生平台使用 `dart:io` 版本，Web 使用基于
// `connectivity_plus` 与 HTTP 探测的版本 /
// Conditionally exports the implementation: the native build uses the `dart:io`
// variant, while the web build uses the `connectivity_plus` + HTTP variant.
export 'connectivity_service_io.dart'
    if (dart.library.html) 'connectivity_service_web.dart';
