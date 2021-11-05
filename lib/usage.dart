import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'package:dio/dio.dart';
import 'utils/network.dart';
import 'utils/db.dart';

class UsagePage extends StatelessWidget {
  UsagePage({Key? key}) : super(key: key);

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("usage"),
        actions: [
          IconButton(
              onPressed: () {
                deleteDb();
              },
              icon: const Icon(Icons.delete_forever)),
          IconButton(
            icon: Icon(Icons.upgrade),
            onPressed: () async {
              print("upgrade");
              dateFramerToDb(DateTime(2021, 10, 18), DateTime.now());

            },
          )
        ],
      ),
      body: UsageContent(
        title: "usage",
      ),
    );
  }
}

class UsageContent extends StatefulWidget {
  UsageContent({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _UsageContentState createState() => _UsageContentState();
}

class _UsageContentState extends State<UsageContent> {
  Future<List<Map<String, dynamic>>> _getAppUsage(
      DateTime from, DateTime to) async {
    appsInfo = await UsageModel.getAppsInfo();

    var _db = await dbHelper.open();
    // List<Map<String, dynamic>> ret = await _db!.rawQuery('''
    //   SELECT * FROM usage LEFT JOIN apps ON usage.appid = apps.id;
    // ''');
    List<Map<String, dynamic>> ret = await _db!.query("usage");
    print(ret.length);
    return ret;
  }

  @override
  Widget build(BuildContext context) {
    DateTime startDate = DateTime(2021, 10, 18);
    DateTime endDate = new DateTime.now();
    Future<List<Map<String, dynamic>>> infos = _getAppUsage(startDate, endDate);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: infos,
      builder: (BuildContext context,
          AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        return Center(
          child: ListView.builder(
            itemBuilder: (BuildContext context, int index) {
              return Column(
                children: [
                  Text(snapshot.data?[index]["id"].toString() ?? '',
                      style: TextStyle(color: Colors.red)),
                  Text((snapshot.data?[index]).toString())
                ],
              );
            },
            itemCount: snapshot.data?.length,
          ),
        );
      },
    );
  }
}

// class PhoneUsage {
//   check() async {
//     String lastFetch = await loadLastFetch();
//     if (lastFetch == "0") {
//       //
//       setLastFetch(DateTime.now().toString());
//     }
//   }

//   Future<Map<String, List<AppUsageInfo>>> getStats(
//       DateTime from, DateTime to) async {
//     var collect = Map<String, List<AppUsageInfo>>();
//     for (DateTime i = from; i.isBefore(to); i = i.add(Duration(days: 1))) {
//       List<AppUsageInfo> infos =
//           await AppUsage.getAppUsage(i, i.add(Duration(days: 1)));
//       collect[i.toString()] = infos;
//     }
//     return collect;
//   }

//   Future<String> getLastFetch() async {
//     Response response = await dio.get("/getLastFetchDate");
//     return response.statusCode == 200 ? response.data.toString() : "";
//   }

//   Future<String> loadLastFetch() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String lastFetch = (prefs.getString('lastDate') ?? "0");
//     print('Last fetch data $lastFetch');
//     return lastFetch;
//   }

//   setLastFetch(String date) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setString('lastDate', date);
//   }

//   void test() {
//     getStats(DateTime(2021, 11, 01), DateTime(2021, 11, 04)).then((e) {
//       print(e);
//     });
//   }
// }
