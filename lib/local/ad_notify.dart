import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'local_db.dart';

/// Conditional daily ad-log reminder.
///
/// At the configured time every day a background isolate runs [check]:
/// it opens the local db, and only when there is NO log for today it pops
/// a notification. The notification carries 推迟1小时 / 推迟3小时 buttons
/// that re-arm the same check. The chain re-registers itself, and
/// rescheduleOnReboot keeps it alive across phone restarts.
class AdNotify {
  static const _checkId = 301; // the daily re-check alarm
  static const _snoozeCheckId = 302; // postponed re-check
  static const _notifId = 100;

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
  static const _body = "今天还没有广告记录。进「广告日志」补一条，或按下推迟。";

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
    WidgetsFlutterBinding.ensureInitialized();
    _initTz();
    await AndroidAlarmManager.initialize();
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

  static DateTime _nextFire(DateTime now, int h, int m) {
    var t = DateTime(now.year, now.month, now.day, h, m);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// re-arm (or clear) the daily check from stored settings —
  /// call on app start so the chain survives force-quits.
  static Future<void> rescheduleFromPrefs() async {
    await AndroidAlarmManager.cancel(_checkId);
    final (on, hour, min) = await current();
    if (!on) return;
    await AndroidAlarmManager.oneShotAt(
        _nextFire(DateTime.now(), hour, min), _checkId, check,
        wakeup: true,
        allowWhileIdle: true,
        exact: true,
        rescheduleOnReboot: true);
  }

  /// runs in a background isolate at the alarm time:
  /// notify only if today has no ad log; always re-arm the next day.
  @pragma('vm:entry-point')
  static Future<void> check() async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    _initTz();
    final (on, hour, min) = await current();
    if (!on) return;
    // keep the chain alive first, whatever the check decides below
    await AndroidAlarmManager.oneShotAt(
        _nextFire(DateTime.now(), hour, min), _checkId, check,
        wakeup: true,
        allowWhileIdle: true,
        exact: true,
        rescheduleOnReboot: true);
    await LocalDb.instance.db;
    final logged = await AdRepo.countOn(DateTime.now());
    if (logged == 0) {
      await _plugin.show(_notifId, 'K.I.T.T. 提示', _body, _details);
    }
  }

  /// postpone: re-run the same check in `minutes` (it stays silent if the
  /// log got filled meanwhile) and pull down today's notification.
  static Future<void> snooze(int minutes) async {
    await _plugin.cancel(_notifId);
    await AndroidAlarmManager.cancel(_snoozeCheckId);
    await AndroidAlarmManager.oneShotAt(
        DateTime.now().add(Duration(minutes: minutes)),
        _snoozeCheckId,
        check,
        wakeup: true,
        allowWhileIdle: true,
        exact: true);
  }

  /// clears a pending reminder notification once the user logs an ad
  static Future<void> clearNotice() async => _plugin.cancel(_notifId);

  /// immediate notification so the user can try the snooze buttons
  static Future<void> test() async {
    await _plugin.show(_notifId, 'K.I.T.T. 测试',
        '这是一条测试通知，可体验推迟按钮', _details);
  }

  // ---- responses ----
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
}

/// background-isolate twin of _handle (app not in foreground).
@pragma('vm:entry-point')
void _onBackgroundResponse(NotificationResponse r) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final id = r.actionId;
  if (id != 'snooze60' && id != 'snooze180') return;
  AndroidAlarmManager.initialize().then((_) =>
      AdNotify.snooze(id == 'snooze60' ? 60 : 180));
}
