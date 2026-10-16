import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily "time to log your ads" reminder, with snooze buttons on the
/// notification itself (推迟 1h / 3h). Settings live in SharedPreferences,
/// the alarm lives in Android's scheduler — no server involved.
class AdNotify {
  static const _dailyId = 100;
  static const _snoozeId = 101;

  static const kOn = 'ad_remind_on';
  static const kHour = 'ad_remind_hour';
  static const kMin = 'ad_remind_min';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// wired by main() to jump to the ad log page when the notification is tapped
  static void Function()? onOpenAds;

  static const _channelId = 'ad_reminder';
  static const _channelName = '广告提醒';
  static const _channelDesc = '每日广告记录提醒';
  static const _body = '该看广告了。记录今日数据，或按下推迟。';

  static const _details = NotificationDetails(
      android: AndroidNotificationDetails(_channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('snooze60', '推迟1小时'),
            AndroidNotificationAction('snooze180', '推迟3小时'),
          ]));

  static void _initTz() {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  static Future<void> init() async {
    _initTz();
    await _plugin.initialize(
        const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/launcher_icon')),
        onDidReceiveNotificationResponse: _handle,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId, _channelName,
            description: _channelDesc, importance: Importance.max));
  }

  /// Android 13+ needs a runtime grant for showing notifications.
  static Future<bool> ensurePermission() async {
    final a = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await a?.requestNotificationsPermission();
    return granted ?? true;
  }

  static void _handle(NotificationResponse r) {
    final id = r.actionId;
    if (id == 'snooze60') {
      snooze(60);
    } else if (id == 'snooze180') {
      snooze(180);
    } else if (r.payload == 'ads' || id == null) {
      onOpenAds?.call();
    }
  }

  // ---- persisted settings ----
  static Future<(bool on, int hour, int min)> current() async {
    final p = await SharedPreferences.getInstance();
    return (
      p.getBool(kOn) ?? false,
      p.getInt(kHour) ?? 21,
      p.getInt(kMin) ?? 0,
    );
  }

  static Future<void> save({required bool on, int? hour, int? min}) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kOn, on);
    if (hour != null) await p.setInt(kHour, hour);
    if (min != null) await p.setInt(kMin, min);
    await rescheduleFromPrefs();
  }

  /// re-arm (or clear) the daily alarm from stored settings —
  /// call on app start so the schedule survives force-quits.
  static Future<void> rescheduleFromPrefs() async {
    await _plugin.cancel(_dailyId);
    final (on, hour, min) = await current();
    if (!on) return;
    await scheduleDaily(hour, min);
  }

  // ---- alarms ----
  static Future<void> scheduleDaily(int hour, int min) async {
    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, min);
    if (!target.isAfter(now)) target = target.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
        _dailyId, 'K.I.T.T. 提示', _body, target, _details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'ads');
  }

  static Future<void> snooze(int minutes) async {
    await _plugin.cancel(_snoozeId);
    final t = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    await _plugin.zonedSchedule(
        _snoozeId, 'K.I.T.T. 推迟提醒', _body, t, _details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'ads');
  }

  /// fires a real notification in 8 seconds so the user can see the buttons
  static Future<void> test() async {
    await _plugin.cancel(_snoozeId);
    final t = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 8));
    await _plugin.zonedSchedule(
        _snoozeId, 'K.I.T.T. 测试', '这是一条测试通知，可体验推迟按钮', t, _details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'ads');
  }
}

/// runs in a background isolate when the app is not in foreground.
@pragma('vm:entry-point')
void _onBackgroundResponse(NotificationResponse r) {
  final id = r.actionId;
  if (id != 'snooze60' && id != 'snooze180') return;
  AdNotify._initTz();
  final plugin = FlutterLocalNotificationsPlugin();
  final minutes = id == 'snooze60' ? 60 : 180;
  plugin.cancel(AdNotify._snoozeId);
  final t = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
  plugin.zonedSchedule(AdNotify._snoozeId, 'K.I.T.T. 推迟提醒', AdNotify._body, t,
      AdNotify._details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'ads');
}
