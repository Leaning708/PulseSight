# AGENTS.md — PulseSight AI 协作指南

本文件为 AI Agent(以及新加入的开发者)提供在本仓库工作的约定。
`CLAUDE.md -> AGENTS.md` 为软链,各工具共享本指南。

## 项目概览

- **项目名**:PulseSight
- **类型**:Flutter 跨平台应用(iOS / Android / macOS / Windows / Linux / Web)
- **语言**:Dart
- **许可证**:GPL-3.0

## 环境与常用命令

```bash
flutter pub get      # 拉取依赖
flutter run          # 运行(debug)
flutter analyze      # 静态分析(提交前须零告警)
flutter test         # 运行全部测试
dart format .        # 格式化
```

## 仓库布局

```
├── lib/              # 应用源码(UI / Logic / Data 分层)
├── test/             # 测试
├── docs/             # 项目文档
├── .agents/skills/   # Agent 技能库(单一事实来源)
├── .claude/skills/   # 软链 -> .agents/skills
├── .dsh/skills/      # 软链 -> .agents/skills
├── CLAUDE.md         # 软链 -> AGENTS.md
├── LICENSE           # GPL-3.0
└── pubspec.yaml      # 依赖与资源声明
```

## Agent 工作约定

1. **技能优先**:`.agents/skills/` 下按主题整理了 Flutter/Dart 技能(架构分层、单元测试、FFI、本地化、路由等)。执行相关任务前先查看并遵循对应技能,不要凭空猜测 API。
2. **不要改动软链**:`.claude/skills`、`.dsh/skills`、`CLAUDE.md` 是指向 `.agents/skills` 与 `AGENTS.md` 的符号链接;修改内容请直接操作目标文件。
3. **架构分层**:遵循 `flutter-apply-architecture-best-practices` 技能的 UI / Logic / Data 分层,UI 层不直接访问数据源。
4. **测试**:新增功能附带测试;修复 bug 前先写复现测试。
5. **静态分析**:改动后运行 `flutter analyze`,确保无 error/warning;提交前用 `dart format` 格式化。
6. **依赖管理**:新增依赖先在 pub.dev 评估维护状态与兼容性;版本冲突参考 `dart-resolve-package-conflicts` 技能。
7. **文档**:面向开发者的文档写入 `docs/`;API 文档使用 `///` 注释(参考 `dart-write-documentation` 技能)。
8. **提交信息**:祈使句、首行 ≤ 50 字符,说明"为什么"而非"是什么"。

## 注意事项

- `pubspec.yaml` 是依赖与资源的唯一事实来源;不要手工编辑生成文件(如 `*.g.dart`)。
- 平台目录(`android/`、`ios/`、`macos/`、`linux/`、`windows/`、`web/`)中的生成文件(如 `GeneratedPluginRegistrant.*`)不要手改。
- 密钥、token 等敏感信息一律通过环境变量或 `.env` 注入(已 gitignore),严禁提交到仓库。
