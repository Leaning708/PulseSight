#ifndef RUNNER_SYSTEM_FONT_LIST_H_
#define RUNNER_SYSTEM_FONT_LIST_H_

namespace flutter {
class BinaryMessenger;
}

// 注册系统字体枚举通道 `pulsesight/fonts`(方法 `list`),镜像 macOS 侧的
// SystemFontListSupport;返回 DirectWrite 系统字体族名(UTF-8 编码)。
void RegisterSystemFontListChannel(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_SYSTEM_FONT_LIST_H_
