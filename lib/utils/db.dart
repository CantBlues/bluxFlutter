import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:app_usage/app_usage.dart';
import 'dart:io';

var dbHelper = DbHelper();
Map<String, int> appsInfo = {};

class DbHelper {
  Database? db;
  Future open() async {
    if (db == null || !db!.isOpen) {
      db = await openDatabase(join(await getDatabasesPath(), "usage.db"),
          version: 1, onCreate: (db, version) async {
        await db.execute(
            'CREATE TABLE usage(id INTEGER PRIMARY KEY AUTOINCREMENT, appid INTEGER, node INTEGER, usage INTEGER);');
        await db.execute(
            'CREATE TABLE apps(id INTEGER PRIMARY KEY AUTOINCREMENT, package TEXT, name TEXT);');
        return;
      });
    }
    return db;
  }

  close() {
    if (db != null) {
      db!.close();
    }
  }
}

class UsageModel {
  UsageModel();

  static Future<Map<String, int>> getAppsInfo() async {
    Database _db = await dbHelper.open();
    final List<Map<String, dynamic>> maps = await _db.query("apps");

    Map<String, int> infos = {};
    maps.forEach((element) {
      infos[element['package']] = element['id'];
    });
    appsInfo = infos;
    return infos;
  }

  static Future<int> addAppInfo(String packageName) async {
    Database _db = await dbHelper.open();
    int id = await _db.insert("apps", {"package": packageName});
    appsInfo[packageName] = id;
    return id;
  }
}

extension usageInfoExtension on AppUsageInfo {
  Future<int> getAppId(String name) async {
    if (appsInfo.containsKey(name)) {
      print("appid: ${appsInfo[name]}");
      return appsInfo[name]!;
    } else {
      return await UsageModel.addAppInfo(name);
    }
  }

  Future<Map<String, dynamic>> toMap() async {
    return {
      "node": int.parse(startDate
          .toString()
          .substring(0, 10)
          .split('-')
          .join()), // Date convert to 8 digits intger
      "usage": usage.inSeconds,
      "appid": await getAppId(packageName)
    };
  }

  insertUsage() async {
    Database _db = await dbHelper.open();
    Map<String, dynamic> map = await toMap();
    await _db.insert("usage", map);
  }
}

dateFramerToDb(DateTime from, DateTime end) async {
  await UsageModel.getAppsInfo();
  for (DateTime i = from; i.isBefore(end); i = i.add(Duration(days: 1))) {
    List<AppUsageInfo> usages =
        await AppUsage.getAppUsage(i, i.add(Duration(days: 1)));
    usages.forEach((element) async {
      await element.insertUsage();
    });
  }
}

deleteDb() async {
  dbHelper.close();
  print("deletefile");
  String dir = await getDatabasesPath();
  List<FileSystemEntity> files = Directory(dir).listSync();
  files.forEach((element) {
    print(element);
    element.delete();
  });
}
