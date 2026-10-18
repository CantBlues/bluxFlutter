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

  static const _remindMin = 0; // fire at the event start itself

  static bool _busy = false; // re-entrancy guard for refresh()

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
    await refresh();
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

  static Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      final p = await SharedPreferences.getInstance();
      final (on, h, m) = await current();
      if (!on) {
        await _purge(p);
        return;
      }
      if (!await hasPermission()) return; // never nag at startup
      final now = DateTime.now();
      final todayK = LocalDb.key(now);
      final tomorrowK = LocalDb.key(now.add(const Duration(days: 1)));

      // tomorrow's reminder must exist every day we're used
      await _ensure(p, tomorrowK, _at(now, h, m).add(const Duration(days: 1)));

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
    } catch (_) {
      // startup path: any hiccup here stays silent
    } finally {
      _busy = false;
    }
  }

  static bool _isDate(String s) {
    final p = s.split('-');
    return p.length == 3 &&
        p.every((e) => int.tryParse(e) != null) &&
        s.length == 10;
  }

  static Future<void> _ensure(
      SharedPreferences p, String dayKey, DateTime start) async {
    final k = '$_evKey$dayKey';
    final ms = start.millisecondsSinceEpoch;
    final prev = _parse(p.getString(k));
    if (prev != null) {
      final exists = await _ch.invokeMethod<bool>('eventExists', {'id': prev.$1});
      if (exists == true && prev.$2 == ms) return; // same time, still there
      await _ch.invokeMethod('deleteEvent', {'id': prev.$1}); // time changed
    }
    final id = await _ch.invokeMethod<int>('createEvent', {
      'title': 'K.I.T.T. 记得记广告 · ${dayKey.substring(5)}',
      'startMs': ms,
      'durationMin': 10,
      'reminderMin': _remindMin,
    });
    // id==null → no calendar account/permission: no key, retried next refresh
    if (id != null) await p.setString(k, '$id:$ms');
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
  /// system-calendar reminder actually fire
  static Future<bool> test() async {
    if (!await hasPermission()) return false;
    final p = await SharedPreferences.getInstance();
    await _drop(p, _testKey); // clear a previous test event
    final start = DateTime.now().add(const Duration(minutes: 2));
    final id = await _ch.invokeMethod<int>('createEvent', {
      'title': 'K.I.T.T. 测试提醒',
      'startMs': start.millisecondsSinceEpoch,
      'durationMin': 5,
      'reminderMin': _remindMin,
    });
    if (id == null) return false;
    await p.setString(_testKey, '$id:${start.millisecondsSinceEpoch}');
    return true;
  }
}
