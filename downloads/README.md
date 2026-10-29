# 今天课程 v0.7.1 审核用安装包

源码：`7c50a5da84a5f44a99b145b32766209ea535cf3d`，分支 `codex/fix-compact-timetable-layout`。作者和提交者：Codex <codex@openai.com>。

[下载 ARM64 APK](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-v0.7.1-review/downloads/today-courses-v0.7.1-arm64.apk)

修复 60% / 80% 紧凑课表中超出配置节次的晚课高度异常及卡片文字裁切，补充扩展时段的时间刻度。包名和签名与旧版一致，支持覆盖安装并保留课程和设置。

本版本提交独立 PR，留待用户 review 和合并。48 项 Flutter 测试、24 项 Kotlin 测试、静态分析、Release Lint 和 ARM64 构建已通过。相邻 PNG 是使用合成课程和中文字体的组件渲染截图，OPPO 真机效果待试装确认。

在本目录执行 `sha256sum --check today-courses-v0.7.1-arm64.apk.sha256` 校验安装包。
