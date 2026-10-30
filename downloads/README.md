# 今天课程 1.0.4

[下载 ARM64 APK](today-courses-v1.0.4-arm64.apk) · [SHA256](today-courses-v1.0.4-arm64.apk.sha256)

版本 1.0.4（15），包名 `com.kitty191.schedule`，应用名“今天课程”。与原版保持相同签名，可覆盖安装 1.0.0–1.0.3，保留课程和设置。独立弹层试验包的数据不会自动迁入。

下课前提醒现单独调度：提前收起课前/课中云不会屏蔽它；到设置的节点时，新发一次“快下课 · 课程名称”提示，并保持系统动态倒计时。新增“下课前提示”分类，请求系统突出显示，默认无声音、无振动。修复分钟刷新覆盖提醒、预览占用唤醒和旧关闭动作误关新提示的问题。

到“我的 → 提醒设置”确认“准时提醒权限”和“下课提示通知”，并在系统设置允许横幅；可查看下一次实际下课提示时间及最近发送结果。“已提交系统”不等于系统已显示流体云；ColorOS 实际展示仍需 OPPO 真机确认。

源码：[`9c72728`](https://github.com/kitty191/schedule/commit/9c72728505c134aa75b6428d5ec006dc2a95d4cb) · [PR #10](https://github.com/kitty191/schedule/pull/10) · [后台审查说明](https://github.com/kitty191/schedule/blob/9c72728505c134aa75b6428d5ec006dc2a95d4cb/docs/ENDING_REMINDER_FIX.md)

本地检查：Flutter analyze、82 项 Flutter 测试、73 项 Kotlin/Robolectric 测试、Android lint、ARM64 release 构建通过；核对原包名/开发签名、版本及 16 KB 对齐。后台测试通过实际调度的 PendingIntent 触发 Manifest 中的接收器，不打开 App、不使用预览按钮，验证普通云关闭后仍按时发布下课提示、只提示一次、重启与关闭、权限和旧系统回退。云环境没有 OPPO 真机。

SHA256：`7c36cdd952c0a16b10cf17fb5ef0913d819178f612da7bae8dca906a5bc5d9ad`

此分支只提供安装包，请勿合并到 main。
