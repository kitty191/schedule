# 今天课程 1.0.3

[下载 ARM64 APK](today-courses-v1.0.3-arm64.apk) · [SHA256](today-courses-v1.0.3-arm64.apk.sha256)

包名 `com.kitty191.schedule`，版本 1.0.3（14），应用名“今天课程”。与原版保持相同签名，可覆盖安装 1.0.0 / 1.0.1 / 1.0.2 并保留原版数据。独立弹层试验包的数据不会自动迁入。

修复流体云收起时倒计时停住的问题：原来的“14分上课”是固定文字，现改用系统计时器，收起与展开均按同一个真实时间持续计时；顶部可能以“07:43”等系统格式显示。上课后切到距离下课的倒计时，阶段文案保留在展开卡片中。保留紫色课程进度、课程教室、节次及教学周，实际排版由 ColorOS 等系统决定。

验证时，到“我的 → 提醒设置”发送课程或下课预览，返回桌面后先不要点开流体云，观察 1–2 分钟；确认数字减少后再展开核对。预览最多 5 分钟。

源码：[`79fc860`](https://github.com/kitty191/schedule/commit/79fc860da1f7f3b4f0feaca324396c00940377c4) · [PR #10](https://github.com/kitty191/schedule/pull/10) · [验证说明](https://github.com/kitty191/schedule/blob/79fc860da1f7f3b4f0feaca324396c00940377c4/docs/LIVE_UPDATE_CARD.md)

检查：Flutter analyze、79 项 Flutter 测试、51 项 Kotlin / Robolectric 测试、Android lint 和 ARM64 release 构建通过。Android 16、17 原生计时器测试验证：不重新发送、不展开，推进六分钟后约 14 分钟变为约 8 分钟；另测试休眠后恢复显示及清除旧固定文字。测试宿主为普通收起通知的原生视图，并非 OPPO 真机。包名、版本、原开发签名及 16 KB APK 对齐已核对，最终 ColorOS 胶囊显示仍需真机确认。

SHA256：`d1139a53bad844416690149cd99991bb64c8d933847115d4ce8191f0bbfe6521`

此分支仅用于下载安装包，请勿合并到 main。
