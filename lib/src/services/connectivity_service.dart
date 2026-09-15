// 连通性检测与网络信息采集服务 / Connectivity detection and network information
// service.
//
// 依据平台条件导出实现：默认导出不含 `dart:io` 的 Web 版本，仅在 `dart:io`
// 可用时改为原生版本 / Conditionally exports the implementation: the
// `dart:io`-free web variant is the default, and the native `dart:io` variant is
// selected only when `dart:io` is available.
export 'connectivity_service_web.dart'
    if (dart.library.io) 'connectivity_service_io.dart';
