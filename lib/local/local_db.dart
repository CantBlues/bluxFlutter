import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local-first storage for everything the phone can own by itself:
/// task types / daily task marks / habit types / habit records /
/// phone-usage day stats. The server is only needed for media, the
/// router and the moon atlas.
///
/// Dates are stored as 'yyyy-MM-dd' text everywhere.
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'kitt_blux.db');
    return openDatabase(path, version: 2,
        onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE task_types(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          weight INTEGER DEFAULT 1,
          classify TEXT,
          sort INTEGER DEFAULT 0)''');
      await db.execute('''
        CREATE TABLE task_marks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          created_at INTEGER,
          UNIQUE(type_id, date))''');
      await db.execute('''
        CREATE TABLE habit_types(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          icon_code INTEGER,
          icon_font TEXT)''');
      await db.execute('''
        CREATE TABLE habit_records(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          habit_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          UNIQUE(habit_id, date))''');
      await db.execute('''
        CREATE TABLE usage_daily(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          pkg TEXT NOT NULL,
          seconds REAL NOT NULL,
          UNIQUE(date, pkg))''');
      await db.execute('''
        CREATE TABLE usage_apps(
          pkg TEXT PRIMARY KEY,
          name TEXT,
          display INTEGER DEFAULT 1)''');
      await _createAdTables(db);
    }, onUpgrade: (db, oldV, newV) async {
      if (oldV < 2) await _createAdTables(db);
    });
  }

  Future<void> _createAdTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ad_games(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ad_phones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE)''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ad_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game TEXT,
        phone TEXT,
        ad TEXT NOT NULL,
        date TEXT NOT NULL,
        ts INTEGER NOT NULL)''');
  }

  static String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime day(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  /// 20220813 style node used by the older usage payload -> yyyy-MM-dd
  static String nodeToKey(int node) =>
      '${node ~/ 10000}-${((node ~/ 100) % 100).toString().padLeft(2, '0')}-${(node % 100).toString().padLeft(2, '0')}';
}

class TaskType {
  int id;
  String name;
  int weight;
  String classify;
  int sort;
  TaskType(
      {required this.id,
      required this.name,
      this.weight = 1,
      this.classify = '',
      this.sort = 0});

  factory TaskType.fromMap(Map<String, dynamic> m) => TaskType(
      id: m['id'] as int,
      name: m['name'] as String,
      weight: (m['weight'] as int?) ?? 1,
      classify: (m['classify'] as String?) ?? '',
      sort: (m['sort'] as int?) ?? 0);

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'weight': weight, 'classify': classify, 'sort': sort};
}

class HabitType {
  int id;
  String name;
  int? iconCode;
  String? iconFont;
  HabitType(
      {required this.id,
      required this.name,
      this.iconCode,
      this.iconFont});

  factory HabitType.fromMap(Map<String, dynamic> m) => HabitType(
      id: m['id'] as int,
      name: m['name'] as String,
      iconCode: m['icon_code'] as int?,
      iconFont: m['icon_font'] as String?);
}

/// ------------------------------------------------------------- tasks ----
class TaskRepo {
  static Future<List<TaskType>> types() async {
    final db = await LocalDb.instance.db;
    final rows = await db.query('task_types', orderBy: 'sort, id');
    return rows.map((e) => TaskType.fromMap(e)).toList();
  }

  /// a starter set so the cockpit is never empty on a fresh install
  static Future<void> ensureSeeded() async {
    final db = await LocalDb.instance.db;
    final c = Sqflite.firstIntValue(await db.rawQuery('select count(*) from task_types'));
    if ((c ?? 0) > 0) return;
    final seed = [
      ['跑步', 'body', 2],
      ['俯卧撑', 'body', 1],
      ['深蹲', 'body', 1],
      ['阅读', 'soul', 3],
      ['冥想', 'soul', 2],
      ['记录', 'steps', 1],
    ];
    for (var i = 0; i < seed.length; i++) {
      await db.insert('task_types',
          {'name': seed[i][0], 'weight': seed[i][2], 'classify': seed[i][1], 'sort': i},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<int> addType(String name, {int weight = 1, String classify = ''}) async {
    final db = await LocalDb.instance.db;
    return db.insert('task_types', {'name': name, 'weight': weight, 'classify': classify, 'sort': 999}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> editType(TaskType t) async {
    final db = await LocalDb.instance.db;
    await db.update('task_types', {'name': t.name, 'weight': t.weight, 'classify': t.classify},
        where: 'id = ?', whereArgs: [t.id]);
  }

  static Future<void> deleteType(int id) async {
    final db = await LocalDb.instance.db;
    await db.delete('task_types', where: 'id = ?', whereArgs: [id]);
    await db.delete('task_marks', where: 'type_id = ?', whereArgs: [id]);
  }

  static Future<void> saveOrder(List<TaskType> types) async {
    final db = await LocalDb.instance.db;
    final batch = db.batch();
    for (var i = 0; i < types.length; i++) {
      batch.update('task_types', {'sort': i}, where: 'id = ?', whereArgs: [types[i].id]);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<int>> markedTypeIds(DateTime day) async {
    final db = await LocalDb.instance.db;
    final rows = await db.query('task_marks',
        columns: ['type_id'], where: 'date = ?', whereArgs: [LocalDb.key(day)]);
    return rows.map((e) => e['type_id'] as int).toList();
  }

  static Future<bool> setMark(int typeId, DateTime day, bool mark) async {
    final db = await LocalDb.instance.db;
    final k = LocalDb.key(day);
    if (mark) {
      await db.insert('task_marks',
          {'type_id': typeId, 'date': k, 'created_at': DateTime.now().millisecondsSinceEpoch},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete('task_marks', where: 'type_id = ? AND date = ?', whereArgs: [typeId, k]);
    }
    return true;
  }

  /// date -> number of marks, last `days` days (dense, for heatmaps)
  static Future<Map<String, int>> contributions({int days = 400}) async {
    final db = await LocalDb.instance.db;
    final from = DateTime.now().subtract(Duration(days: days));
    final rows = await db.query('task_marks',
        columns: ['date', 'COUNT(*) as c'],
        where: 'date >= ?',
        whereArgs: [LocalDb.key(from)],
        groupBy: 'date');
    return {for (final r in rows) r['date'] as String: (r['c'] as int)};
  }

  static Future<int> markCountOn(DateTime day) async {
    final db = await LocalDb.instance.db;
    final v = await db.rawQuery(
        'select count(*) c from task_marks where date = ?', [LocalDb.key(day)]);
    return v.first['c'] as int;
  }

  /// dates a single type was marked (value forced to 1 for the heatmap)
  static Future<Map<String, int>> contributionsFor(String name) async {
    final db = await LocalDb.instance.db;
    final rows = await db.rawQuery('''
      select m.date d from task_marks m join task_types t on t.id = m.type_id
      where t.name = ? group by m.date''', [name]);
    return {for (final r in rows) r['d'] as String: 1};
  }

  /// consecutive day streak ending today (or yesterday if today empty)
  static Future<int> streak() async {
    final db = await LocalDb.instance.db;
    final rows = await db.query('task_marks', columns: ['date'], groupBy: 'date', orderBy: 'date desc');
    final days = rows.map((e) => LocalDb.day(e['date'] as String)).toSet();
    if (days.isEmpty) return 0;
    var cur = DateTime.now();
    if (!days.contains(cur)) {
      cur = cur.subtract(const Duration(days: 1));
      if (!days.contains(cur)) return 0;
    }
    var n = 0;
    while (days.contains(cur)) {
      n++;
      cur = cur.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// per-type totals for this and last month: name -> [thisMonth, lastMonth]
  static Future<Map<String, List<int>>> monthCompare() async {
    final db = await LocalDb.instance.db;
    final now = DateTime.now();
    final thisStart = LocalDb.key(DateTime(now.year, now.month, 1));
    final lastStart = LocalDb.key(DateTime(now.year, now.month - 1, 1));
    final res = await db.rawQuery('''
      select t.name n,
        sum(case when m.date >= ? then 1 else 0 end) cur,
        sum(case when m.date >= ? and m.date < ? then 1 else 0 end) prev
      from task_marks m join task_types t on t.id = m.type_id
      where m.date >= ?
      group by t.id order by t.sort, t.id''',
        [thisStart, lastStart, thisStart, lastStart]);
    return {
      for (final r in res)
        r['n'] as String: [r['cur'] as int? ?? 0, r['prev'] as int? ?? 0]
    };
  }

  /// days since the last mark for each classify=='body' type
  static Future<List<Map<String, dynamic>>> overdueBody() async {
    final db = await LocalDb.instance.db;
    final res = await db.rawQuery('''
      select t.id, t.name, max(m.date) last from task_types t
      left join task_marks m on m.type_id = t.id
      where t.classify = 'body'
      group by t.id''');
    final now = DateTime.now();
    return [
      for (final r in res)
        if (r['last'] != null)
          {
            'name': r['name'],
            'days': now.difference(LocalDb.day(r['last'] as String)).inDays
          }
        else
          {'name': r['name'], 'days': 999}
    ];
  }
}

/// ------------------------------------------------------------ habits ----
class HabitRepo {
  static Future<List<HabitType>> types() async {
    final db = await LocalDb.instance.db;
    final rows = await db.query('habit_types', orderBy: 'id');
    return rows.map((e) => HabitType.fromMap(e)).toList();
  }

  static Future<int> addType(String name, {int? iconCode, String? iconFont}) async {
    final db = await LocalDb.instance.db;
    return db.insert('habit_types',
        {'name': name, 'icon_code': iconCode, 'icon_font': iconFont},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> deleteType(int id) async {
    final db = await LocalDb.instance.db;
    await db.delete('habit_types', where: 'id = ?', whereArgs: [id]);
    await db.delete('habit_records', where: 'habit_id = ?', whereArgs: [id]);
  }

  static Future<bool> isRecorded(int habitId, DateTime day) async {
    final db = await LocalDb.instance.db;
    final r = await db.query('habit_records',
        where: 'habit_id = ? AND date = ?', whereArgs: [habitId, LocalDb.key(day)]);
    return r.isNotEmpty;
  }

  /// toggle today's record, returns new state (true = recorded)
  static Future<bool> toggleToday(int habitId) async {
    final db = await LocalDb.instance.db;
    final k = LocalDb.key(DateTime.now());
    final existing =
        await db.query('habit_records', where: 'habit_id = ? AND date = ?', whereArgs: [habitId, k]);
    if (existing.isNotEmpty) {
      await db.delete('habit_records', where: 'habit_id = ? AND date = ?', whereArgs: [habitId, k]);
      return false;
    }
    await db.insert('habit_records', {'habit_id': habitId, 'date': k});
    return true;
  }

  static Future<int> recordedTodayCount() async {
    final db = await LocalDb.instance.db;
    final r = await db.rawQuery(
        'select count(*) c from habit_records where date = ?', [LocalDb.key(DateTime.now())]);
    return r.first['c'] as int;
  }

  /// 12 lists (month index 0..11) of recorded days for the current year
  static Future<List<List<int>>> yearMatrix(int habitId) async {
    final db = await LocalDb.instance.db;
    final year = DateTime.now().year;
    final rows = await db.query('habit_records',
        columns: ['date'], where: 'habit_id = ? AND date LIKE ?', whereArgs: [habitId, '$year-%']);
    final out = List.generate(12, (_) => <int>[]);
    for (final r in rows) {
      final d = LocalDb.day(r['date'] as String);
      out[d.month - 1].add(d.day);
    }
    return out;
  }

  static Future<List<String>> recentDates(int habitId, {int limit = 500}) async {
    final db = await LocalDb.instance.db;
    final rows = await db.query('habit_records',
        columns: ['date'],
        where: 'habit_id = ?',
        whereArgs: [habitId],
        orderBy: 'date desc',
        limit: limit);
    return rows.map((e) => e['date'] as String).toList();
  }
}

/// ------------------------------------------------------------- usage ----
class UsageRepo {
  /// upsert day rows produced by usage_stats collection
  static Future<void> savePeriod(List<Map> periodUsage) async {
    final db = await LocalDb.instance.db;
    final batch = db.batch();
    for (final day in periodUsage) {
      final node = day['node'];
      final key = node is int ? LocalDb.nodeToKey(node) : node.toString();
      for (final app in (day['data'] as List? ?? [])) {
        batch.insert('usage_daily',
            {'date': key, 'pkg': app['name'], 'seconds': app['usage']},
            conflictAlgorithm: ConflictAlgorithm.replace);
        batch.insert('usage_apps', {'pkg': app['name']},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, Object?>>> apps({bool displayOnly = false}) async {
    final db = await LocalDb.instance.db;
    return db.query('usage_apps',
        where: displayOnly ? 'display = 1' : null, orderBy: 'name');
  }

  static Future<void> setDisplay(String pkg, bool display) async {
    final db = await LocalDb.instance.db;
    await db.update('usage_apps', {'display': display ? 1 : 0}, where: 'pkg = ?', whereArgs: [pkg]);
  }

  static Future<void> setName(String pkg, String name) async {
    final db = await LocalDb.instance.db;
    await db.update('usage_apps', {'name': name}, where: 'pkg = ?', whereArgs: [pkg]);
  }

  /// daily series for one pkg (null = summed over display apps)
  /// returns [{node: yyyy-MM-dd, usage: seconds}] oldest first
  static Future<List<Map<String, Object?>>> dailySeries({String? pkg}) async {
    final db = await LocalDb.instance.db;
    if (pkg == null) {
      return db.rawQuery('''
        select u.date node, sum(u.seconds) usage from usage_daily u
        join usage_apps a on a.pkg = u.pkg where a.display = 1
        group by u.date order by u.date''');
    }
    return db.query('usage_daily',
        columns: ['date node', 'seconds usage'],
        where: 'pkg = ?',
        whereArgs: [pkg],
        orderBy: 'date');
  }

  /// top apps on a day
  static Future<List<Map<String, Object?>>> topByDate(String date) async {
    final db = await LocalDb.instance.db;
    return db.rawQuery('''
      select u.pkg, a.name, u.seconds usage from usage_daily u
      left join usage_apps a on a.pkg = u.pkg
      where u.date = ? order by u.seconds desc limit 12''', [date]);
  }

  static Future<double> dayTotal(String date) async {
    final db = await LocalDb.instance.db;
    final r = await db.rawQuery('select sum(seconds) s from usage_daily where date = ?', [date]);
    return (r.first['s'] as num?)?.toDouble() ?? 0;
  }

  static Future<List<Map<String, Object?>>> heatmap() async {
    final db = await LocalDb.instance.db;
    return db.rawQuery('''
      select date, sum(seconds) s from usage_daily
      group by date order by date''');
  }
}

/// --------------------------------------------------------- ad logging ----
/// Daily "watched an ad" journal: which game, which phone/device, the ad
/// name typed in, and the moment it happened. All local.
class AdRepo {
  // ---- quick-pick dictionaries ----
  static Future<List<String>> _names(String table) async {
    final db = await LocalDb.instance.db;
    final rows = await db.query(table, columns: ['name'], orderBy: 'id');
    return rows.map((e) => e['name'] as String).toList();
  }

  static Future<List<String>> games() => _names('ad_games');
  static Future<List<String>> phones() => _names('ad_phones');

  static Future<void> addGame(String name) async {
    final db = await LocalDb.instance.db;
    await db.insert('ad_games', {'name': name},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> addPhone(String name) async {
    final db = await LocalDb.instance.db;
    await db.insert('ad_phones', {'name': name},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> removeGame(String name) async {
    final db = await LocalDb.instance.db;
    await db.delete('ad_games', where: 'name = ?', whereArgs: [name]);
  }

  static Future<void> removePhone(String name) async {
    final db = await LocalDb.instance.db;
    await db.delete('ad_phones', where: 'name = ?', whereArgs: [name]);
  }

  // ---- log ----
  static Future<int> addLog(
      {String? game, String? phone, required String ad, DateTime? at}) async {
    final db = await LocalDb.instance.db;
    final when = at ?? DateTime.now();
    return db.insert('ad_logs', {
      'game': game,
      'phone': phone,
      'ad': ad,
      'date': LocalDb.key(when),
      'ts': when.millisecondsSinceEpoch,
    });
  }

  static Future<void> deleteLog(int id) async {
    final db = await LocalDb.instance.db;
    await db.delete('ad_logs', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, Object?>>> recentLogs({int limit = 100}) async {
    final db = await LocalDb.instance.db;
    return db.query('ad_logs', orderBy: 'ts desc', limit: limit);
  }

  static Future<int> countOn(DateTime day) async {
    final db = await LocalDb.instance.db;
    final r = await db.rawQuery(
        'select count(*) c from ad_logs where date = ?', [LocalDb.key(day)]);
    return r.first['c'] as int;
  }

  /// dense per-day counts for the last `days` days: date -> number
  static Future<Map<String, int>> dailySeries({int days = 14}) async {
    final db = await LocalDb.instance.db;
    final from = LocalDb.key(
        DateTime.now().subtract(Duration(days: days - 1)));
    final rows = await db.query('ad_logs',
        columns: ['date', 'COUNT(*) c'],
        where: 'date >= ?',
        whereArgs: [from],
        groupBy: 'date');
    final found = {for (final r in rows) r['date'] as String: r['c'] as int};
    final out = <String, int>{};
    for (var i = days - 1; i >= 0; i--) {
      final k = LocalDb.key(DateTime.now().subtract(Duration(days: i)));
      out[k] = found[k] ?? 0;
    }
    return out;
  }

  /// most-logged games: name -> count
  static Future<Map<String, int>> topGames({int limit = 6}) async {
    final db = await LocalDb.instance.db;
    final rows = await db.rawQuery('''
      select game g, count(*) c from ad_logs
      where g is not null and g != '' group by g
      order by c desc limit ?''', [limit]);
    return {for (final r in rows) r['g'] as String: r['c'] as int};
  }
}
