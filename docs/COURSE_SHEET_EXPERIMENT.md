# 课程底部编辑面板（1.0.1 正式功能）

课程弹层试验已经用户确认采用，合入 main。正式包沿用应用名“今天课程”、包名 `com.kitty191.schedule` 和原有签名，版本 1.0.1（12），可覆盖 1.0.0 并保留正式版数据。

## 操作

- 点击日程中的课程/日程、课表卡片、全部课程或重叠列表中的某门课，从底部打开可直接修改的面板。
- 名称、教室、节次/时间、颜色、备注、保存和删除均保留；导入课程继续按实际日期上课。
- 保存才写入。取消、下拉或系统返回不会保存草稿；关闭后保留原来的页面与浏览位置。
- 新增课程和日程继续使用整页方式。
- 提醒设置可拖动横条/标题区下拉收起；短拉回弹。列表内容先滚动，回到顶部后继续下拉才带动面板。
- 点击外部空白、完成/取消或系统返回仍可关闭；内部时间/节次选择器不会错误关闭面板。
- 使用 CupertinoSheetRoute 的拖动与滚动协调；背景主页面不随面板键盘缩小，避免横屏溢出。

## 正式版构建与验证

```bash
source /workspace/.setup/schedule/activate.sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
cd android
./gradlew :app:testDebugUnitTest :app:lintRelease
```

CI 与默认构建均生成正式包，不再设置试验包环境变量或附加包名。77 项 Flutter 测试、26 项 Kotlin 调度测试覆盖保存/取消、拖动关闭/回弹、滚动协调、内部选择器、系统返回、有限日期和横屏键盘。

[下载 1.0.1 正式包](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-v1.0.1/downloads/today-courses-v1.0.1-arm64.apk)

## 原试验归档

[试验实现提交 5c3093a](https://github.com/kitty191/schedule/commit/5c3093a4280a144c33286e337aa5ad112466ec65) 和 [独立试验 APK](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-sheets-preview-1/downloads/today-courses-sheets-preview-1.apk) 保留供对照。试验应用包名为 `com.kitty191.schedule.sheets`，与正式版数据互相独立；正式版不会自动读取试验版新增或修改的数据。

旧导航可在 1.0.0 提交 `aa95204cf14483c2256706e2a32577768999215f` 中查看。

云端没有已授权的 Android 真机或 macOS / Xcode；本次验证 Android 构建与自动化交互，iOS 原生编译仍未验证。
