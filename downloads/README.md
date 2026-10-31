# 今天课程 1.0.7

[下载正式 ARM64 APK](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-v1.0.7/downloads/today-courses-v1.0.7-arm64.apk) · [SHA256](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-v1.0.7/downloads/today-courses-v1.0.7-arm64.apk.sha256)

版本 1.0.7（18），应用名“今天课程”，正式包名 `com.kitty191.schedule`。可直接覆盖原版 1.0.0 / 1.0.1 / 1.0.2 / 1.0.3 / 1.0.4 / 1.0.5 / 1.0.6，保留原版课程和设置。

本版本在 Android 13+ 使用课程日历的精确闹钟权限，新增“1 分钟后自动测试”：回到桌面，第 1 分钟发布测试云、第 2 分钟切换、第 3 分钟提示下课、第 4 分钟撤下。使用真实系统闹钟和原生接收器，手动打开 App 不会伪造首次测试成功。测试不保存到课表。保留原有计时到期保护、独立下课提示和后台排程。ColorOS 实际后台和展示策略仍需手机核对。

试验包 `com.kitty191.schedule.sheets` 仍为独立应用；试验数据不会自动迁入正式版。

[后台自动测试及审查](../docs/AUTOMATIC_BACKGROUND_TEST.md) · [到零卡住问题审查](../docs/COUNTDOWN_BOUNDARY_FIX.md) · [后台提醒审查及真机核对](../docs/BACKGROUND_REMINDERS.md) · [下课提醒审查](../docs/ENDING_REMINDER_FIX.md) · [流体云说明](../docs/LIVE_UPDATE_CARD.md) · [课程编辑面板](../docs/COURSE_SHEET_EXPERIMENT.md) · [1.0.0 历史审查](../docs/RELEASE_AUDIT_1.0.0.md)
