# 今天课程·弹层试验

[下载独立试验 APK](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-sheets-preview-1/downloads/today-courses-sheets-preview-1.apk) · [SHA256](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-sheets-preview-1/downloads/today-courses-sheets-preview-1.apk.sha256)

包名 `com.kitty191.schedule.sheets`，版本 1.0.1-sheets.1（11），应用名“今天课程·弹层试验”。与原版 1.0.0 并排安装，两份数据互相独立，首次打开可添加课程或导入同一份 .ics。

点击已有课程从底部打开可修改的面板；提醒面板支持拖动横条/标题区关闭，列表先滚动，回到顶部后继续下拉关闭。保存才写入课程，取消/下拉保留原数据。

不喜欢时直接打开原版“今天课程”，无需重装、降级或卸载原版。

[源码 5c3093a](https://github.com/kitty191/schedule/commit/5c3093a4280a144c33286e337aa5ad112466ec65) · [试验说明](https://github.com/kitty191/schedule/blob/codex/experiment-course-sheets/docs/COURSE_SHEET_EXPERIMENT.md)

77 项 Flutter 测试、26 项 Kotlin 测试、静态分析、Release Lint 和 ARM64 构建通过。安装包已核对独立包名、启动器名、Activity、签名及 ZIP 对齐。相邻预览图使用合成课程与中文字体渲染，实际手感需试装确认。

源码和安装包作者、提交者均为 Codex <codex@openai.com>。下载分支独立存放二进制文件，不合并至源码。
