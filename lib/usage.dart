import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:dio/dio.dart';
import 'utils/network.dart';

bool test(int i) {
  try {
    DateTime startDate = DateTime(2018, 01, 01);
    DateTime endDate = new DateTime.now();
    // DateTime startDate = endDate.subtract(Duration(days: 6));
    DateTime cur = startDate;
    while (cur.isBefore(endDate)) {
      cur = cur.add(Duration(days: 1));
      print("$startDate   $cur");
      startDate = startDate.add(Duration(days: 1));
    }
    var infos = AppUsage.getAppUsage(startDate, endDate);
  } on AppUsageException catch (exception) {
    print(exception);
  }
  return true;
}

class UsagePage extends StatelessWidget {
  UsagePage({Key? key}) : super(key: key);

  @override
  Widget build(context) {
    return Scaffold(
        appBar: AppBar(title: Text("usage")),
        body: Container(child: AppUsageView()));
  }
}

class AppUsageView extends StatefulWidget {
  @override
  _APPUsageViewState createState() => _APPUsageViewState();

  static Future<List<Map>> getUsage() async {
    List<Map> periodUsage = [];
    DateTime endDate = new DateTime.now();
    DateTime startDate = endDate.subtract(Duration(days: 6));
    DateTime cur = startDate;

    while (cur.isBefore(endDate)) {
      int sum = 0;
      cur = cur.add(Duration(days: 1));
      int node =
          int.parse(startDate.toString().substring(0, 10).split('-').join());
      Map today = {"node": node, "data": []};

      var origin = await UsageStats.queryUsageStats(startDate, cur);

      for (var element in origin) {
        if (int.parse(element.totalTimeInForeground!) != 0) {
          int usage =
              (int.parse(element.totalTimeInForeground!) / 1000).round();
          var tmp = {
            "name": element.packageName!,
            "usage": usage,
          };
          if (usage > 0) {
            sum += int.parse(element.totalTimeInForeground!);
            today["data"].add(tmp);
          }
        }
      }
      today["data"].add({
        "name": "sum",
        "usage": sum,
      });
      periodUsage.add(today);
      startDate = startDate.add(Duration(days: 1));
    }

    return periodUsage;
  }

  static recordPhoneUsage() async {
    var data = await AppUsageView.getUsage();
    dioLara.post("/api/phone/usages", data: data).then((value) {
      print(value.data);
    });
  }
}

class _APPUsageViewState extends State<AppUsageView> {
  List _infos = ["waiting"];

  showUsage() async {
    var data = await AppUsageView.getUsage();
    List output = [];
    for (var element in data) {
      output.add(element["node"]);
      for (var app in element["data"]) {
        output.add(app);
      }
    }
    dioLara.post("/api/phone/usages", data: data).then((value) {
      print(value.data);
    });
    setState(() {
      _infos = output;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        itemCount: _infos.length,
        itemBuilder: ((context, index) {
          if (_infos[index].toString() == "waiting") {
            return Column(
              children: [
                TextButton(onPressed: () => showUsage(), child: Text("Tap")),
                CircularProgressIndicator()
              ],
            );
          }
          return Text(_infos[index].toString());
        }));
  }
}
