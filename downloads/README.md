# 今天课程 1.0.6

[下载 APK](today-courses-v1.0.6-arm64.apk) · [SHA256](today-courses-v1.0.6-arm64.apk.sha256)

正式包名 com.kitty191.schedule，版本 1.0.6（17），同原开发签名。可直接覆盖旧版，保留课程及设置，无需先装 1.0.5。

修正课前倒计时到零后仍保留旧通知的问题：有效期限制到当前计时终点，上课后用独立通知更新为下课倒计时；保留独立后台排程及诊断。后台拦截或厂商未遵循到期设置的情况仍需手机核对。

源码：[2f08277be1ed182c0791f3bd4937c407f3bde093](https://github.com/kitty191/schedule/commit/2f08277be1ed182c0791f3bd4937c407f3bde093)

[审查说明](https://github.com/kitty191/schedule/blob/2f08277be1ed182c0791f3bd4937c407f3bde093/docs/COUNTDOWN_BOUNDARY_FIX.md)

此分支只保存下载文件，请勿合并至 main。
