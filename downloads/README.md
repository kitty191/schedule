# 今天课程 1.0.1

[下载正式 ARM64 APK](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-v1.0.1/downloads/today-courses-v1.0.1-arm64.apk) · [SHA256](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-v1.0.1/downloads/today-courses-v1.0.1-arm64.apk.sha256)

版本 1.0.1（12），应用名“今天课程”，正式包名 `com.kitty191.schedule`，与 1.0.0 签名相同，可直接覆盖原版并保留课程和设置。

课程底部编辑面板和提醒设置下拉关闭已正式合入 main：[源码 073c080](https://github.com/kitty191/schedule/commit/073c080077888b07c57c86463ab08b4a7768301a) · [PR #9](https://github.com/kitty191/schedule/pull/9)。

保存才写入课程；取消、下拉或系统返回不保存草稿。提醒列表先正常滚动，回到顶部后继续下拉即可关闭面板，短拉回弹。

原独立试验应用 `com.kitty191.schedule.sheets` 仍可保留，其数据不会自动迁入正式版。

77 项 Flutter 测试、26 项 Kotlin 调度测试、静态分析、Release Lint 和 ARM64 构建通过。包名、版本、启动器名称、原版签名及 ZIP 对齐已核对。合并后的文件树与已验证构建完全一致。

源码及合并、安装包提交均使用 Codex <codex@openai.com> 身份。云端未验证真机熄屏/省电表现和 iOS 原生编译。

在本目录运行 `sha256sum --check today-courses-v1.0.1-arm64.apk.sha256` 可核对安装包。
