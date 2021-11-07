import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:app_usage/app_usage.dart';
import 'dart:io';
import 'network.dart';
import 'package:dio/dio.dart';

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
    return await _db.insert("apps", {"package": packageName});
  }
}

extension usageInfoExtension on AppUsageInfo {
  Future<int> getAppId(String name) async {
    if (appsInfo.containsKey(name)) {
      return appsInfo[name]!;
    } else {
      int id = await UsageModel.addAppInfo(name);
      appsInfo[name] = id;
      return id;
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
  from = DateTime(from.year, from.month, from.day);
  for (DateTime i = from; i.isBefore(end); i = i.add(Duration(days: 1))) {
    int sumTime = 0;
    int startDate = int.parse(i.toString().substring(0, 10).split('-').join());

    print(startDate);
    List<AppUsageInfo> usages =
        await AppUsage.getAppUsage(i, i.add(Duration(days: 1)));
    await Future.forEach(usages, (AppUsageInfo element) async {
      await element.insertUsage();
      sumTime += element.usage.inSeconds;
    });
    Database _db = await dbHelper.open();
    if (sumTime > 0) {
      await _db
          .insert("usage", {"appid": 0, "usage": sumTime, "node": startDate});
    }
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

DateTime stringToDate(String node) {
  return DateTime(int.parse(node.substring(0, 4)),
      int.parse(node.substring(4, 6)), int.parse(node.substring(6, 8)));
}

getUsage() async {
  Database _db = await dbHelper.open();
  List result = await _db.query("usage", limit: 1, orderBy: "id desc");
  if (result.length == 0) {
    await dateFramerToDb(
        DateTime.now().add(const Duration(days: -365 * 2)), DateTime.now());
  } else {
    DateTime lastGet = stringToDate(result[0]["node"].toString());
    await dateFramerToDb(lastGet, DateTime.now());
  }
}

fetchUsage() async {
  await getUsage(); // insert to local database
  Response lastDate = await dio.get("/usage/getLastDate");
  if (lastDate.statusCode == 200 && lastDate.data != null) {
    //query date from this date then send to server
    Database _db = await dbHelper.open();
    List last = await _db.query("usage", limit: 1, orderBy: "id desc");
    int localLast = last[0]["node"];
    if (localLast > int.parse(lastDate.data)) {
      List usage = await _db
          .query("usage", where: "node >= ?", whereArgs: [lastDate.data]);
      List apps = await _db.query("apps");
      dio.post("/usage/sendData",
          data: {"usage": usage, "apps": apps, "last": lastDate.data});
    }
  }
}

// server return list of usage, take the first node and last node as boundary that ready to delete on local database
// server return apps data, delete all record on local database.apps
// insert data retrieved by server to local db
loadUsageFromServer() async {}
