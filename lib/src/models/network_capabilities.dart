// 网络诊断能力枚举与当前平台能力集 / Network diagnostic capabilities and the
// capability set of the current platform.
//
// 依据平台条件导出实现：原生平台报告完整能力，Web 仅报告浏览器沙箱内可实现的
// 能力 / Conditionally exports the implementation: the native build reports the
// full capability set, while the web build reports only what the browser sandbox
// supports.
export 'network_capabilities_io.dart'
    if (dart.library.html) 'network_capabilities_web.dart';
