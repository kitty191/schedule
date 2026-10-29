# 今天课程 1.0.0

[下载 ARM64 APK](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-v1.0.0/downloads/today-courses-v1.0.0-arm64.apk) · [SHA256](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-v1.0.0/downloads/today-courses-v1.0.0-arm64.apk.sha256)

版本 1.0.0（10），包名 `com.kitty191.schedule`，与 0.7.x 使用相同签名，可覆盖安装并保留课程和设置。

源码：[aa95204cf14483c2256706e2a32577768999215f](https://github.com/kitty191/schedule/commit/aa95204cf14483c2256706e2a32577768999215f)，分支 `codex/release-1.0.0`。源码与安装包提交作者、提交者均为 Codex <codex@openai.com>。

[整体审查记录](https://github.com/kitty191/schedule/blob/codex/release-1.0.0/docs/RELEASE_AUDIT_1.0.0.md)

本次修复扩展空白格排错时间、密集重叠卡片、同日多次导入、导入失败/取消预览状态、前台恢复与保存竞态、重叠提醒结束后重现、数据加载失败恢复、大字体选择器和历史日期、横屏 Dock 遮挡等问题。

已通过 66 项 Flutter 测试、26 项 Kotlin 调度测试、Flutter analyze、Release Lint、ARM64 构建、签名与 ZIP 对齐检查。预览图使用合成课程与中文字体渲染，不含个人课表。

云环境无已授权的 Android 真机、模拟器及 macOS / Xcode；OPPO 权限弹窗、熄屏/重启/省电策略和流体云展现仍需真机确认，iOS 原生编译尚未验证。

在本目录运行 `sha256sum --check today-courses-v1.0.0-arm64.apk.sha256` 可核对文件。

本分支独立存放安装包，源码 PR 留待用户审核，不合并此下载分支。
