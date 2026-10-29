# 今天课程 v0.7.2 审核用安装包

源码提交：`0472eb2615d90fc774fb6e02296f8e326544f49a`，作者和提交者为 Codex <codex@openai.com>。

[下载 ARM64 APK](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-v0.7.2-review/downloads/today-courses-v0.7.2-arm64.apk) · [Review PR #4](https://github.com/kitty191/schedule/pull/4)

修正左侧 20:00 / 21:00 刻度：与常规时间列共用字体和水平中心，文字垂直中心对齐对应横线。适配 60% / 80% 密度与系统大字体，小时显示模式使用同一布局。保留上一版的晚课高度及文字裁切修复。

包名和签名与旧版一致，可覆盖安装并保留课程、课表和提醒设置。版本 0.7.2（9）。源码留待用户 review 和合并。

50 项 Flutter 测试、24 项 Kotlin 测试、静态分析、Release Lint 和 ARM64 构建已通过。相邻 PNG 是使用合成课程和中文字体的组件截图；OPPO 真机效果待试装确认。

在本目录执行 `sha256sum --check today-courses-v0.7.2-arm64.apk.sha256` 校验安装包。
