# 今天课程 v0.7.0 Android 测试包

[下载 ARM64 APK](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-v0.7.0/downloads/today-courses-v0.7.0-arm64.apk)

源码提交：`b003e862d61d9af4feeba6c167bb41f4a4a3853e`，作者和提交者为 Codex <codex@openai.com>。

我的 → 提醒设置：分别自定义上课前提醒与下课前流体云提醒，支持 1–1440 分钟。可切换是否使用导入文件的课前提醒。与旧版保持相同包名及签名，可直接覆盖安装，保留课程与设置。

SHA256 见相邻 `.sha256` 文件；在本目录执行 `sha256sum --check today-courses-v0.7.0-arm64.apk.sha256`。

已通过 Flutter analyze、44 项 Flutter 测试、24 项 Kotlin 测试、Android Release Lint 和 ARM64 构建。系统展现需在手机实测。iOS 延续普通课前通知，仍需 macOS / Xcode 验证。
