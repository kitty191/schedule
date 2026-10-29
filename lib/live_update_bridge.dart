import 'package:flutter/services.dart';

class LiveUpdateStatus {
  const LiveUpdateStatus({
    required this.supported,
    required this.notificationsEnabled,
    required this.promotionAllowed,
    required this.active,
    required this.promoted,
    this.exactAllowed = false,
  });

  factory LiveUpdateStatus.fromMap(Map<Object?, Object?> value) =>
      LiveUpdateStatus(
        supported: value['supported'] == true,
        notificationsEnabled: value['notificationsEnabled'] == true,
        promotionAllowed: value['promotionAllowed'] == true,
        active: value['active'] == true,
        promoted: value['promoted'] == true,
        exactAllowed: value['exactAllowed'] == true,
      );

  final bool supported;
  final bool notificationsEnabled;
  final bool promotionAllowed;
  final bool active;
  final bool promoted;
  final bool exactAllowed;
}

class LiveUpdateBridge {
  static const channel = MethodChannel('com.kitty191.schedule/live_updates');

  Future<LiveUpdateStatus> status() => _invoke('status');
  Future<LiveUpdateStatus> requestPermission() => _invoke('permission');
  Future<LiveUpdateStatus> configure(Map<String, Object> data) =>
      _invoke('configure', data);
  Future<LiveUpdateStatus> preview(Map<String, Object> course) =>
      _invoke('preview', course);
  Future<LiveUpdateStatus> previewEnding(Map<String, Object> course) =>
      _invoke('previewEnding', course);
  Future<LiveUpdateStatus> stop() => _invoke('stop');
  Future<void> openSettings() => channel.invokeMethod<void>('settings');
  Future<void> openExactSettings() =>
      channel.invokeMethod<void>('exactSettings');

  Future<LiveUpdateStatus> _invoke(
    String method, [
    Map<String, Object>? data,
  ]) async {
    final result = await channel.invokeMapMethod<Object?, Object?>(
      method,
      data,
    );
    if (result == null) {
      throw PlatformException(
        code: 'empty_response',
        message: '系统没有返回提醒状态，请重试。',
      );
    }
    return LiveUpdateStatus.fromMap(result);
  }
}
