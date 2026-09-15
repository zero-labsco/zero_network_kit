// 网络诊断能力枚举与当前平台能力集 / Network diagnostic capabilities and the
// capability set of the current platform.
//
// 依据平台条件导出实现：默认导出不含 `dart:io` 的 Web 能力集，仅在 `dart:io`
// 可用时改为报告完整能力的原生版本 / Conditionally exports the implementation:
// the `dart:io`-free web capability set is the default, and the native variant
// reporting the full capability set is selected only when `dart:io` is available.
export 'network_capabilities_web.dart'
    if (dart.library.io) 'network_capabilities_io.dart';
