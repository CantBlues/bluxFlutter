import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/network.dart';
import 'package:dio/dio.dart';

class UsagePage extends StatefulWidget {
  UsagePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _UsagePageState createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  Future<List<AppUsageInfo>> _getAppUsage(DateTime from, DateTime to) async {
    List<AppUsageInfo> infos = await AppUsage.getAppUsage(from, to);
    return infos;
  }

  @override
  Widget build(BuildContext context) {
    var ttt = PhoneUsage();
    ttt.test();
    DateTime startDate = DateTime(2021, 07, 18);
    DateTime endDate = new DateTime.now();
    Future<List<AppUsageInfo>> infos = _getAppUsage(startDate, endDate);
    return Scaffold(
      body: FutureBuilder<List<AppUsageInfo>>(
        future: infos,
        builder:
            (BuildContext context, AsyncSnapshot<List<AppUsageInfo>> snapshot) {
          return Center(
            child: ListView.builder(
              itemBuilder: (BuildContext context, int index) {
                return Column(
                  children: [
                    Text(snapshot.data?[index].appName ?? '',
                        style: TextStyle(color: Colors.red)),
                    Text((snapshot.data?[index]).toString())
                  ],
                );
              },
              itemCount: snapshot.data?.length,
            ),
          );
        },
      ),
    );
  }
}

class PhoneUsage {
  check() async {
    String lastFetch = await loadLastFetch();
    if (lastFetch == "0") {
      //
      setLastFetch(DateTime.now().toString());
    }
  }

  Future<Map<String, List<AppUsageInfo>>> getStats(
      DateTime from, DateTime to) async {
    var collect = Map<String, List<AppUsageInfo>>();
    for (DateTime i = from; i.isBefore(to); i = i.add(Duration(days: 1))) {
      List<AppUsageInfo> infos =
          await AppUsage.getAppUsage(i, i.add(Duration(days: 1)));
      collect[i.toString()] = infos;
    }
    return collect;
  }

  Future<String> getLastFetch() async {
    Response response = await dio.get("/getLastFetchDate");
    return response.statusCode == 200 ? response.data.toString() : "";
  }

  Future<String> loadLastFetch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String lastFetch = (prefs.getString('lastDate') ?? "0");
    print('Last fetch data $lastFetch');
    return lastFetch;
  }

  setLastFetch(String date) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastDate', date);
  }

  void test() {
    getStats(DateTime(2021, 05, 01), DateTime(2021, 07, 24)).then((e) {
      print(e);
    });
  }
}
