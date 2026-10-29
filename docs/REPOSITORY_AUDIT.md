# 仓库完整性审查（v0.6.0）

审查对象：`kitty191/schedule` 的 main 分支、已提交文件清单、工作区被忽略的文件、Android 自动构建记录，以及下载分支/Release 的安装包。

## 已检查的内容

| 类别 | 结果 |
| --- | --- |
| Flutter 源码及原生通道 | Dart 页面、数据层、Android Kotlin 通知与调度、iOS Swift 通知源码均在版本控制中 |
| 数据库与依赖 | Drift 生成文件、pubspec.yaml、pubspec.lock 已提交；构建不依赖工作区独有的数据库源码 |
| 平台项目与资源 | Android Manifest/资源/构建配置、iOS Xcode 项目/资源/Info.plist 齐全 |
| 测试 | 界面、手势、导入、迁移、时间设置和 Kotlin 调度测试均已提交；课表夹具使用独立示例数据 |
| 自动构建 | Android 工作流已提交，最近 main 分支构建成功；本次增加 Wrapper 校验 |
| 安装包 | 既有版本的 APK 位于对应 builds/android-v* 下载分支，Release 正文提供下载入口；main 保留源码 |

## 补齐和修正

- Flutter 模板忽略了 `android/gradlew`、`gradlew.bat`、`gradle/wrapper/gradle-wrapper.jar`。现补齐标准 Wrapper 文件，并保留 Unix 脚本可执行权限。
- Wrapper 使用 Gradle 9.3.1 bin 发行包，固定发行包 SHA256；JAR 与官方公布的 Wrapper SHA256 一致，校验文件一同提交。
- 新增通用的 `docs/BUILDING.md`，从干净克隆说明工具版本、构建命令、数据库生成、iOS 临时插件包及签名边界。
- 当前版本从仅含版本控制文件的全新目录执行构建检查，避免把本机生成文件误认为已上传源码。最终结果见本版本 Release 验证说明。

## 合理排除的文件

SDK 路径、构建产物、IDE/Gradle/Dart 缓存、自动生成的插件注册文件、Flutter iOS 临时包、签名私钥及用户个人课表不上传。它们不是遗漏的应用源码。iOS 原生构建仍需 macOS / Xcode 验证。

## 提交身份

从本次提交起，作者和提交者设置为 `Codex <codex@openai.com>`。GitHub 显示的账号或头像取决于该邮箱的账号关联；提交身份不等于更换 GitHub 登录账号。
