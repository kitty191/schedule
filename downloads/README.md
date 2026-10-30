# 今天课程 1.0.6

[下载正式 ARM64 APK](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-v1.0.6/downloads/today-courses-v1.0.6-arm64.apk) · [SHA256](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-v1.0.6/downloads/today-courses-v1.0.6-arm64.apk.sha256)

版本 1.0.6（17），应用名“今天课程”，正式包名 `com.kitty191.schedule`。可直接覆盖原版 1.0.0 / 1.0.1 / 1.0.2 / 1.0.3 / 1.0.4 / 1.0.5，保留原版课程和设置。

本版本修复课前倒计时到零后旧卡片保留过久的问题：旧卡片的有效期设为上课时刻，上课后改用独立通知 ID 的下课倒计时。系统回调延迟时由系统到期撤下旧卡片。保留提前登记多个独立系统闹钟，减少单次后台回调丢失对后续上下课提醒的影响。新增后台运行、电池优化设置入口及实际后台回调记录。OPPO 请允许后台活动，并按需锁定后台；强行停止会撤销系统闹钟，不能由 App 绕过。保留系统自动倒计时。保留紫色进度、上下课时刻、课程教室、节次及教学周；实际流体云排版由手机系统决定。保留课程底部编辑面板及提醒下拉关闭手势。

试验包 `com.kitty191.schedule.sheets` 仍为独立应用；试验数据不会自动迁入正式版。

[到零卡住问题审查](../docs/COUNTDOWN_BOUNDARY_FIX.md) · [后台提醒审查及真机核对](../docs/BACKGROUND_REMINDERS.md) · [下课提醒审查](../docs/ENDING_REMINDER_FIX.md) · [流体云说明](../docs/LIVE_UPDATE_CARD.md) · [课程编辑面板](../docs/COURSE_SHEET_EXPERIMENT.md) · [1.0.0 历史审查](../docs/RELEASE_AUDIT_1.0.0.md)
