# 今天课程

一个轻量的课程表 App。主界面只展示今天的课程和下一节课，右上角菜单提供添加课程、全部课程、课程提醒和学期起始日期。

Flutter / Dart 编写界面和业务逻辑，Riverpod 管理状态，Drift / SQLite 保存本地数据，Kotlin 和 Swift 负责系统提醒。无需登录，课程数据保存在手机本地。

## 当前功能

- 添加、编辑、删除每周重复课程，设置星期、上课/下课时间、教室和课程颜色。
- 今天的课程按时间排序，突出显示下一节或正在上的课程；已结束的课程淡化显示。
- 从“全部课程”管理其他星期的课程。学期日期用于显示教学周，第一周从所选日期所在周的周一开始。
- 课程提醒可选择提前 5 / 10 / 15 / 30 分钟，默认关闭，需要用户主动开启。
- Android：课前倒计时 → 正在上课 → 下课撤下。点击通知进入 App，或选择“结束提醒”结束当前这次课程提醒。
- Android 16+：沿用已在 OPPO / ColorOS 真机验证成功的 Live Updates 通知方式。收起胶囊显示简短状态，系统展开界面显示课程名、时间和教室。系统控制最终外观。
- Android 旧系统：使用普通持续通知。
- iOS 15+：共享课程界面和本地存储，通过系统每周重复的普通通知提醒上课。此版未接入 ActivityKit / 灵动岛。

当前课程每周重复，不包含单双周、节假日、特定教学周或教务导入。跨午夜的课程需要拆分添加。课程重叠时，Android 优先显示最早开始且未结束的一门。

## 安装与真机检查

从本仓库 Releases 下载 ARM64 APK。应用包名保持 `com.kitty191.schedule`，可覆盖安装此前的“上岛测试”；名称改为“今天课程”。当前 APK 使用同一云环境的开发签名，供安装测试，尚未配置正式商店发布签名。

1. 添加一门今天的课程，将上课时间设为几分钟后，下课时间设为其后几分钟。
2. 打开右上角 `···` → 课程提醒，开启“课前提醒”，允许系统通知。
3. Android 在同一面板中开启“允许准时提醒”。如果实时提醒未获允许，进入系统通知设置开启对应权限。
4. 回到桌面，检查课前胶囊、展开的课程信息、上课状态和下课撤下。
5. 也可点击“发送课程预览”立即发送已有课程的通知；Android 预览在 5 分钟后结束。结束预览后恢复正常调度。
6. 修改或删除课程，检查旧提醒是否更新/撤下；重新打开 App 检查课程是否保留。

提醒可靠性：Android 用 AlarmManager 调度，提醒配置另存原生存储，手机重启、应用更新和时区/时间变化后重新计算。开启准时提醒可使用 exact alarms，否则系统可能延后。系统深度省电仍可能限制后台更新频率；通知 chronometer 由系统显示倒计时，下课设置自动过期。强制停止应用后，需要重新打开才会恢复调度。iOS 使用系统日历触发器；为预览保留系统配额，最多为 60 门课程启用重复提醒，超过时会在 App 中明确提示。

## 开发

已验证：Flutter **3.47.8** / Dart **3.13.7**、JDK **21**、Android SDK **36**。iOS 需要 macOS 和 Xcode；当前 Linux 云环境未编译或真机验证 iOS 原生代码。

当前云环境先执行：

```bash
source /workspace/.setup/schedule/activate.sh
```

在仓库目录执行：

```bash
flutter pub get --enforce-lockfile
# 修改数据库模型后才需要重新生成；生成文件已提交
# dart run build_runner build
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
cd android
./gradlew :app:testDebugUnitTest :app:lintRelease
```

APK 输出：`build/app/outputs/flutter-apk/app-release.apk`。

测试覆盖：SQLite 关闭/重开后的增删改和设置持久化、时间校验、提醒同步失败时仍保留课程、课程添加/编辑/删除流程、拒绝权限、窄屏大字体布局，以及 Kotlin 调度器的提前边界、下课、跨午夜、跨周、重叠、手动结束、删除和夏令时。

## 代码组织

```text
lib/data/                   Drift 数据库、课程时间逻辑、Riverpod 控制器
lib/features/               今天、全部课程、课程编辑、提醒设置面板
lib/live_update_bridge.dart Flutter 与原生提醒的通道
android/app/src/main/kotlin/ Android 通知、持久化调度、重启恢复
android/app/src/test/        Android 调度逻辑单元测试
ios/Runner/AppDelegate.swift iOS 普通课程通知
test/                       数据层与界面流程测试
```
