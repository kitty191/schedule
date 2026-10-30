# 今天课程 1.0.2

[下载 ARM64 APK](today-courses-v1.0.2-arm64.apk) · [SHA256](today-courses-v1.0.2-arm64.apk.sha256)

包名 `com.kitty191.schedule`，版本 1.0.2（13），应用名“今天课程”。与原版保持相同签名，可覆盖安装 1.0.0 / 1.0.1 并保留原版数据。独立弹层试验包的数据不会自动迁入。

流体云使用紫色分段进度、开课节点和书本跟随图标，提供上下课时刻、课程教室、节次、教学周和系统倒计时。实际排版由 ColorOS 等系统决定，无法保证与 iOS 参考图相同。

从“我的 → 提醒设置”发送课程预览或下课预览，返回桌面展开顶部提醒查看。预览使用模拟时刻，最多显示 5 分钟。

源码：[`33046c1`](https://github.com/kitty191/schedule/commit/33046c1961bcc471c1a00ab85085f7621d3af2ad) · [功能与真机验证说明](https://github.com/kitty191/schedule/blob/33046c1961bcc471c1a00ab85085f7621d3af2ad/docs/LIVE_UPDATE_CARD.md)

检查：Flutter analyze、79 项 Flutter 测试、45 项 Kotlin / Robolectric 测试（Android 24/36/37）、Android lint 和 ARM64 release 构建通过；包名、版本、原开发签名及 16 KB APK 对齐已核对。云环境没有 OPPO 真机，最终流体云外观需安装确认。

SHA256：`a0a6bc7128ab8b73321da12d2937722198131676ea84995dd21e6c5b53969950`

此分支仅用于下载安装包，请勿合并到 main。
