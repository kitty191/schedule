# 从 GitHub 源码构建

Android 已在 Linux 云环境和 GitHub Actions 验证。iOS 项目及 Swift 源码已提交，但仍需要 macOS / Xcode 编译及真机验证。

## Android 工具

- Flutter 3.47.8 stable（Dart 3.13.7），加入 PATH。
- JDK 21，设置 JAVA_HOME。
- Android SDK：platform-tools、platforms;android-36、build-tools;36.0.0、ndk;28.2.13676358、cmake;3.22.1。
- 设置 ANDROID_HOME 指向 SDK，运行 `flutter doctor --android-licenses` 接受 SDK 许可。
- Gradle 9.3.1 由已提交的 Wrapper 下载，发行包 SHA256 和 Wrapper JAR SHA256 均已固定。

```bash
git clone https://github.com/kitty191/schedule.git
cd schedule
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
cd android
./gradlew :app:testDebugUnitTest :app:lintRelease
```

输出：`build/app/outputs/flutter-apk/app-release.apk`。纯 Android Gradle 任务需要先执行 `flutter pub get` / Flutter 构建以生成 SDK 路径等本机配置；`./gradlew --version` 可以独立检查 Wrapper。

数据库生成文件 `lib/data/database.g.dart` 已提交；只有修改数据表时才需执行 `dart run build_runner build`。依赖由 `pubspec.lock` 固定。

## iOS

在 macOS 安装 Flutter 和 Xcode、完成 `flutter doctor` 后：

```bash
flutter pub get --enforce-lockfile
flutter build ios --simulator --debug --no-codesign
```

项目使用 Flutter 生成的 Swift Package Manager 插件集成，`ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage` 由 Flutter 工具生成。请通过 Flutter 构建生成它，再用 Xcode 打开 `ios/Runner.xcworkspace`。安装到真机还需要自己的 Apple 签名配置。

## 本机文件和签名

`android/local.properties`、Flutter 插件注册文件、Swift 临时包、SDK 和依赖缓存由本机工具生成，不上传。签名私钥、口令和用户导入的个人课表也不上传。

当前下载分支中的测试包由同一开发签名构建，支持覆盖安装。自己在另一台机器构建的默认开发签名可能不同；正式发行需要配置发布签名。
