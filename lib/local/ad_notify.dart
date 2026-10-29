import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_db.dart';

/// Daily ad-log reminder, delegated to the system calendar.
///
/// The old AlarmManager background check got eaten by OEM battery managers,
/// so instead [refresh] (run at app start and after every record) writes a
/// one-off event for *tomorrow* at the chosen time into the phone calendar —
/// the calendar app's own reminder alarm is what pops the notification.
/// When every game has been logged today, the not-yet-fired event for
/// today is deleted ("完成即撤"). Permission prompts only ever happen from
/// user gestures; startup stays silent.
class AdNotify {
  static const _ch = MethodChannel('kitt/calendar');

  static const kOn = 'ad_remind_on';
  static const kHour = 'ad_remind_hour';
  static const kMin = 'ad_remind_min';
  static const _evKey = 'ad_ev_'; // + yyyy-MM-dd -> "eventId:startMs"

  /// one-off "next ad" reminder (created right after a record), kept apart
  /// from the daily keys so the daily prune never eats it
  static const _nextKey = 'ad_next_ev';
  static const kNextMin = 'ad_next_min'; // last lead time the user picked

  static const _remindMin = 0; // fire at the event start itself

  /// refreshes are serialised instead of dropped: a refresh requested while
  /// another one is running (e.g. toggling the switch during the boot-time
  /// sync) would otherwise be skipped and no event would ever be written
  static Future<void> _queue = Future<void>.value();

  /// last failure reason; null when the last sync succeeded
  static String? _lastError;

  static Future<(bool on, int hour, int min)> current() async {
    final p = await SharedPreferences.getInstance();
    return (
      p.getBool(kOn) ?? false,
      p.getInt(kHour) ?? 21,
      p.getInt(kMin) ?? 0,
    );
  }

  /// returns null on success, otherwise the reason nothing was written
  static Future<String?> save(
      {required bool on, int? hour, int? min}) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kOn, on);
    if (hour != null) await p.setInt(kHour, hour);
    if (min != null) await p.setInt(kMin, min);
    await refresh();
    return on ? _lastError : null;
  }

  // ---- permission ----

  /// silent check — safe at startup
  static Future<bool> hasPermission() async {
    try {
      return await _ch.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// prompts the system dialog — only call from a user gesture
  static Future<bool> ensurePermission() async {
    try {
      final ok = await _ch
          .invokeMethod<bool>('ensurePermission')
          .timeout(const Duration(seconds: 60));
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---- scheduling ----

  static DateTime _at(DateTime day, int h, int m) =>
      DateTime(day.year, day.month, day.day, h, m);

  /// serialised so overlapping calls never lose an update
  static Future<void> refresh() {
    _queue = _queue.then((_) => _refreshOnce()).catchError((Object _) {});
    return _queue;
  }

  static Future<void> _refreshOnce() async {
    _lastError = null;
    try {
      final p = await SharedPreferences.getInstance();
      await _pruneNext(p);
      final (on, h, m) = await current();
      if (!on) {
        await _purge(p);
        return;
      }
      if (!await hasPermission()) {
        _lastError = '未获得日历权限';
        return;
      }
      final now = DateTime.now();
      final todayK = LocalDb.key(now);
      final tomorrowK = LocalDb.key(now.add(const Duration(days: 1)));

      // tomorrow's reminder must exist every day we're used
      final ok = await _ensure(
          p, tomorrowK, _at(now, h, m).add(const Duration(days: 1)));
      if (!ok) return; // reason already recorded

      // today: keep only while tasks are unfinished and the time not passed
      final games = await AdRepo.games();
      final counts = await AdRepo.gameCountsOn(now);
      final allDone =
          games.isNotEmpty && games.every((g) => (counts[g] ?? 0) > 0);
      final tk = '$_evKey$todayK';
      if (allDone) {
        await _drop(p, tk);
      } else if (_at(now, h, m).isAfter(now)) {
        await _ensure(p, todayK, _at(now, h, m));
      } else {
        await _drop(p, tk); // already fired — tidy up the key
      }

      // prune stale day keys (yesterday's fired event etc.)
      for (final k in p.getKeys().where((k) => k.startsWith(_evKey)).toList()) {
        final d = k.substring(_evKey.length);
        if (d == todayK || d == tomorrowK || !_isDate(d)) continue;
        if (LocalDb.day(d).isBefore(LocalDb.day(todayK))) await _drop(p, k);
      }
    } catch (e) {
      // startup path: any hiccup here stays silent
      _lastError ??= '日历同步失败：$e';
    }
  }

  static bool _isDate(String s) {
    final p = s.split('-');
    return p.length == 3 &&
        p.every((e) => int.tryParse(e) != null) &&
        s.length == 10;
  }

  /// creates/keeps the event for [dayKey]; false means nothing is in the
  /// system calendar (and [_lastError] says why)
  static Future<bool> _ensure(
      SharedPreferences p, String dayKey, DateTime start) async {
    final k = '$_evKey$dayKey';
    final ms = start.millisecondsSinceEpoch;
    final prev = _parse(p.getString(k));
    if (prev != null) {
      final exists =
          await _ch.invokeMethod<bool>('eventExists', {'id': prev.$1});
      if (exists == true && prev.$2 == ms) return true; // same time, still there
      await _ch.invokeMethod('deleteEvent', {'id': prev.$1}); // time changed
    }
    final r = await _createEvent(
        title: 'K.I.T.T. 记得记广告 · ${dayKey.substring(5)}',
        start: start,
        durationMin: 10);
    if (r.id == null) {
      _lastError = r.error ?? '写入日历失败';
      return false;
    }
    if (r.error != null) _lastError = r.error;
    await p.setString(k, '${r.id}:$ms');
    return true;
  }

  static Future<({int? id, String? error})> _createEvent({
    required String title,
    required DateTime start,
    required int durationMin,
  }) async {
    try {
      final res = await _ch.invokeMethod<Map>('createEvent', {
        'title': title,
        'startMs': start.millisecondsSinceEpoch,
        'durationMin': durationMin,
        'reminderMin': _remindMin,
      });
      return (
        id: (res?['id'] as num?)?.toInt(),
        error: res?['error'] as String?,
      );
    } on MissingPluginException {
      return (id: null, error: '当前平台不支持系统日历');
    } on PlatformException catch (e) {
      return (id: null, error: e.message ?? e.code);
    } catch (e) {
      return (id: null, error: '$e');
    }
  }

  static Future<void> _drop(SharedPreferences p, String k) async {
    final prev = _parse(p.getString(k));
    if (prev != null) {
      try {
        await _ch.invokeMethod('deleteEvent', {'id': prev.$1});
      } catch (_) {}
    }
    await p.remove(k); // drop the key even if the delete failed
  }

  static Future<void> _purge(SharedPreferences p) async {
    for (final k in p.getKeys().where((k) => k.startsWith(_evKey)).toList()) {
      await _drop(p, k);
    }
  }

  /// the one-off "next ad" event only lives until it fires; drop the stale
  /// key (the calendar row itself is left alone)
  static Future<void> _pruneNext(SharedPreferences p) async {
    final prev = _parse(p.getString(_nextKey));
    if (prev == null) return;
    if (prev.$2 <= DateTime.now().millisecondsSinceEpoch) {
      await p.remove(_nextKey);
    }
  }

  /// one-off reminder [minutes] from now ("下一条广告"), today only.
  /// null on success, otherwise the reason nothing was written
  static Future<String?> remindIn(int minutes) async {
    if (minutes <= 0) return null;
    if (!await hasPermission()) return '未获得日历权限';
    final now = DateTime.now();
    final start = now.add(Duration(minutes: minutes));
    // 仅当日：跨过午夜的提醒不写
    final midnight =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    if (!start.isBefore(midnight)) {
      return '今天只剩 ${midnight.difference(now).inMinutes} 分钟';
    }
    final p = await SharedPreferences.getInstance();
    await _drop(p, _nextKey); // a newer reminder replaces the old one
    final hm = '${start.hour.toString().padLeft(2, '0')}:'
        '${start.minute.toString().padLeft(2, '0')}';
    final r = await _createEvent(
        title: 'K.I.T.T. 下一条广告 · $hm', start: start, durationMin: 10);
    if (r.id == null) return r.error ?? '写入日历失败';
    await p.setString(_nextKey, '${r.id}:${start.millisecondsSinceEpoch}');
    await p.setInt(kNextMin, minutes);
    return r.error;
  }

  /// the next ad has been recorded — withdraw the pending "next ad" event
  static Future<void> clearNext() async {
    final p = await SharedPreferences.getInstance();
    await _drop(p, _nextKey);
  }

  static (int, int)? _parse(String? v) {
    if (v == null) return null;
    final i = v.indexOf(':');
    if (i < 0) return null;
    final id = int.tryParse(v.substring(0, i));
    final ms = int.tryParse(v.substring(i + 1));
    return (id != null && ms != null) ? (id, ms) : null;
  }

  static const _testKey = '${_evKey}test';

  /// one-shot event starting in 2 minutes so the user can see the
  /// system-calendar reminder actually fire; null on success, otherwise the
  /// reason nothing was written
  static Future<String?> test() async {
    if (!await hasPermission()) return '未获得日历权限';
    final p = await SharedPreferences.getInstance();
    await _drop(p, _testKey); // clear a previous test event
    final start = DateTime.now().add(const Duration(minutes: 2));
    final r = await _createEvent(
        title: 'K.I.T.T. 测试提醒', start: start, durationMin: 5);
    if (r.id == null) return r.error ?? '写入日历失败';
    await p.setString(_testKey, '${r.id}:${start.millisecondsSinceEpoch}');
    return r.error;
  }
}
