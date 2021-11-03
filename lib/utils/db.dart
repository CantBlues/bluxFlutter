import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:app_usage/app_usage.dart';

var model = DbModel();
var db = model.db;

class DbModel {
  DbModel._internal() {
    init();
    getAppsInfo();
  }
  static DbModel _singleton = DbModel._internal();
  factory DbModel() => _singleton;
  late final Database _database;
  Map<String, int> _appsInfo = {};
  Map<String, int> get appsInfo => _appsInfo;
  Database get db => _database;
  void init() async {
    _database = await openDatabase(join(await getDatabasesPath(), "blux.db"),
        onCreate: (db, version) {
      return db.execute(
          '''CREATE TABLE usage(id INTEGER PRIMARY KEY AUTOINCREMENT, appid INTEGER, node INTEGER, usage INTEGER);
             CREATE TABLE apps(id INTEGER PRIMARY KEY AUTOINCREMENT, package TEXT, name TEXT);
          ''');
    });
  }

  Future<Map<String, int>> getAppsInfo() async {
    final List<Map<String, dynamic>> maps = await _database.query("apps");

    Map<String, int> infos = {};
    maps.forEach((element) {
      infos[element['package']] = element['id'];
    });
    _appsInfo = infos;
    return infos;
  }

  Future<int> addAppInfo(String packageName) async {
    await _database.insert("apps", {"package": packageName});
    List<Map<String, dynamic>> info = await _database
        .query("apps", where: "package = ?", whereArgs: [packageName]);
    print(info);
    _appsInfo[packageName] = info[0]["id"];
    return info[0]["id"];
  }
}

extension usageInfoExtension on AppUsageInfo {
  Future<int> getAppId(String name, Map<String, int> apps) async {
    if (apps.containsKey(name)) {
      return apps[name]!;
    }
    return await model.addAppInfo(name);
  }

  Future<Map<String, dynamic>> toMap() async {
    return {
      "node": int.parse(startDate
          .toString()
          .substring(0, 10)
          .split('-')
          .join()), // Date convert to 8 digits intger
      "duration": usage.inSeconds,
      "appid": await getAppId(packageName, model.appsInfo)
    };
  }
}
