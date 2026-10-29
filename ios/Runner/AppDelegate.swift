import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var reminderChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CourseReminders") else { return }
    let channel = FlutterMethodChannel(name: "com.kitty191.schedule/live_updates", binaryMessenger: registrar.messenger())
    reminderChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      let center = UNUserNotificationCenter.current()
      switch call.method {
      case "status": self.replyStatus(result)
      case "permission":
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
          if let error = error { self.fail(error, result) } else { self.replyStatus(result) }
        }
      case "configure":
        guard let data = call.arguments as? [String: Any],
              let courses = data["courses"] as? [[String: Any]] else {
          result(FlutterError(code: "invalid_data", message: "课程数据无效。", details: nil)); return
        }
        let enabled = data["enabled"] as? Bool ?? false
        if enabled && courses.count > 60 {
          result(FlutterError(code: "notification_limit", message: "iOS 系统提醒最多支持 60 门重复课程，请减少课程后重试。", details: nil)); return
        }
        let lead = data["leadMinutes"] as? Int ?? 10
        // Repeat calendar triggers survive process exit and device restart.
        center.getPendingNotificationRequests { pending in
          center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("course-") }.map { $0.identifier })
          if !enabled { self.replyStatus(result); return }
          let group = DispatchGroup()
          let errors = NSLock()
          var schedulingError: Error?
          for course in courses {
            guard let id = course["id"] as? Int, let name = course["name"] as? String,
                  let weekday = course["weekday"] as? Int, let start = course["startMinute"] as? Int else { continue }
            let adjusted = start - lead
            let dayShift = adjusted < 0 ? -1 : 0
            let minute = (adjusted + 1440) % 1440
            let isoDay = (weekday - 1 + dayShift + 7) % 7 + 1
            var date = DateComponents()
            date.weekday = isoDay % 7 + 1 // Apple Sunday=1, ISO Monday=1.
            date.hour = minute / 60
            date.minute = minute % 60
            let content = UNMutableNotificationContent()
            content.title = name
            let location = course["location"] as? String ?? ""
            content.body = "\(lead)分钟后上课 · \(location.isEmpty ? "未设置教室" : location)"
            content.sound = .default
            group.enter()
            center.add(UNNotificationRequest(identifier: "course-\(id)", content: content,
              trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true))) { error in
              if let error = error { errors.lock(); schedulingError = error; errors.unlock() }
              group.leave()
            }
          }
          group.notify(queue: .main) {
            if let error = schedulingError { self.fail(error, result) } else { self.replyStatus(result) }
          }
        }
      case "preview":
        guard let course = call.arguments as? [String: Any] else { result(FlutterMethodNotImplemented); return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
          if let error = error { self.fail(error, result); return }
          guard granted else {
            DispatchQueue.main.async { result(FlutterError(code: "permission_denied", message: "请在系统设置中允许通知。", details: nil)) }; return
          }
          let content = UNMutableNotificationContent()
          content.title = course["name"] as? String ?? "课程预览"
          content.body = course["location"] as? String ?? "课程提醒预览"
          content.sound = .default
          center.add(UNNotificationRequest(identifier: "preview", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))) { error in
            if let error = error { self.fail(error, result) }
            else { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.replyStatus(result) } }
          }
        }
      case "stop":
        center.removePendingNotificationRequests(withIdentifiers: ["preview"])
        center.removeAllDeliveredNotifications()
        self.replyStatus(result)
      case "settings", "exactSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  private func replyStatus(_ result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      center.getDeliveredNotifications { delivered in
        DispatchQueue.main.async {
          result([
            "supported": false,
            "notificationsEnabled": settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
            "promotionAllowed": false,
            "active": !delivered.isEmpty,
            "promoted": false,
            "exactAllowed": true,
          ])
        }
      }
    }
  }

  private func fail(_ error: Error, _ result: @escaping FlutterResult) {
    DispatchQueue.main.async { result(FlutterError(code: "notification_error", message: error.localizedDescription, details: nil)) }
  }
}
