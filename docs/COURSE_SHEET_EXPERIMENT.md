# 课程弹层交互试验

原版基线：`codex/release-1.0.0`，提交 `aa95204cf14483c2256706e2a32577768999215f`。试验分支：`codex/experiment-course-sheets`。本分支不修改原版分支，供试装和 review。

## 操作

- 点击日程中的课程/日程、课表卡片、全部课程或重叠列表中的某门课，从底部打开可直接修改的面板。
- 保留名称、教室、节次/时间、颜色、备注、保存及删除；导入课程仍保留实际日期。
- 保存才写入课程。点击取消、下拉或系统返回关闭面板时，未保存的编辑不写入。
- 新增课程和新增日程继续使用原来的整页方式。
- 提醒设置的横条和标题区可直接下拉收起；短拉回弹。内容区域先正常滚动，滚到顶部后继续下拉才带动面板。
- 点击面板外空白、完成/取消或系统返回仍可关闭。内部时间/节次选择器独立打开，不会错误关闭编辑面板。
- 面板共用 Flutter 的 CupertinoSheetRoute 和它提供的滚动控制器；背景主页面不随面板键盘缩小，避免横屏溢出。

## 试装和切回

[下载试验 APK](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-sheets-preview-1/downloads/today-courses-sheets-preview-1.apk)

试验应用名为 **今天课程·弹层试验**，包名 `com.kitty191.schedule.sheets`。与原版并排安装，保留原应用及其数据，避免 Android 禁止降级安装导致无法直接用回旧版。

试验版首次打开为空，可添加课程或导入同一份 .ics 文件。两份数据和通知权限互相独立，不自动同步；正式数据可继续留在原版。不喜欢时直接打开原版“今天课程”，无需卸载、降级或重装原版。

[原版 1.0.0 APK](https://github.com/kitty191/schedule/raw/refs/heads/builds/android-v1.0.0/downloads/today-courses-v1.0.0-arm64.apk)

源码可直接切回原分支：

```bash
git switch codex/release-1.0.0
```

提醒拖动修复独立于课程弹层：`bc062f9`（面板/滚动协调）及 `eb63397`（键盘下背景页面稳定）。即使不采用课程编辑试验，也可以单独保留这两项修复。

## 构建

```bash
source /workspace/.setup/schedule/activate.sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
ORG_GRADLE_PROJECT_schedulePreview=true flutter build apk --release --target-platform android-arm64
cd android
ORG_GRADLE_PROJECT_schedulePreview=true ./gradlew :app:testDebugUnitTest :app:lintRelease
```

`ORG_GRADLE_PROJECT_schedulePreview=true` 仅改变 Android 包名和启动器显示名。未设置时仍构建原包名，因此本分支 CI 和提供的安装包都明确开启该参数。Flutter/Dart 层、数据库格式和通知接入不变。

## 验证

覆盖面板拖动跟手、关闭/回弹、滚动与收起协调、空白关闭、系统返回、课程保存/取消、内部选择器、导入日期保留、日程编辑及横屏键盘。保留原有 1.0.0 回归测试：77 项 Flutter 测试、26 项 Kotlin 测试、静态分析、Release Lint 和 ARM64 构建通过，并用中文字体渲染课程、提醒和拖动过程。安装包已核对独立包名、启动器名称、Activity、签名及 ZIP 对齐。

云端无已授权真机或 macOS / Xcode；Android 实际手感及系统级流体云仍需试装确认，本次未编译 iOS。
