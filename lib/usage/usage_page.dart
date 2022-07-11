import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';
import '../utils/network.dart';
import 'package:provider/provider.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';

class UsagePage extends StatelessWidget {
  UsagePage({Key? key}) : super(key: key);

  @override
  Widget build(context) {
    return Scaffold(
        appBar: AppBar(title: Text("Phone Usage Stats")),
        floatingActionButton: FloatingActionButton(
            child: Icon(Icons.search),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: ((context) => AppUsageView())))),
        body: Container(child: PhoneStat()));
  }
}

class PhoneStat extends StatefulWidget {
  @override
  _PhoneStatState createState() => _PhoneStatState();
}

class _PhoneStatState extends State<PhoneStat> {
  AppProvider app = AppProvider();
  bool loading = true;

  showApps() {
    showDialog(
        context: context,
        builder: (context) {
          int selectedApp = 0;
          List<Widget> apps = [];
          app.apps.forEach((element) {
            var name = (element["name"] != null && element["name"] != "")
                ? element["name"]
                : element["package_name"];
            apps.add(Text(name));
          });
          return GestureDetector(
            child: CupertinoPicker(
                itemExtent: 20,
                onSelectedItemChanged: (v) => selectedApp = v,
                children: apps),
            onDoubleTap: () async {
              Navigator.of(context).pop();
              var curApp = app.apps[selectedApp];
              app.appId = curApp["id"];
              var data = await app.getData();

              setState(() {
                app.name = curApp["name"] != null && curApp["name"] != ""
                    ? curApp["name"]
                    : curApp["package_name"];

                app.data = data;
              });
            },
          );
        });
  }

  @override
  void initState() {
    dioLara.get("/api/phone/apps").then((value) async {
      var data = jsonDecode(value.data);
      int sumId = 0;
      for (var element in data["data"]) {
        if (element["package_name"] == "sum") {
          sumId = element["id"];
          break;
        }
      }
      app.appId = sumId;
      var usageStats = await app.getData();
      setState(() {
        app.apps = data["data"];
        app.data = usageStats;
        loading = false;
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Provider<AppProvider>(
            create: (_) => app,
            child: loading
                ? CircularProgressIndicator()
                : Column(
                    children: [
                      ConstrainedBox(
                          constraints: BoxConstraints(minHeight: 100),
                          child: UsageContribution()),
                      Expanded(child: UsageLineChart()),
                      Center(
                          child: TextButton(
                              onPressed: () => showApps(),
                              child: Text(
                                app.name,
                                style: TextStyle(fontSize: 30),
                              )))
                    ],
                  )));
  }
}

class AppProvider {
  AppProvider();
  String name = "sum";
  int appId = 0;
  List apps = [];
  List data = [];
  Future<List> getData() async {
    var response = await dioLara.get("/api/phone/usages/$appId");
    var data = jsonDecode(response.data);
    return data["data"];
  }
}

class UsageContribution extends StatefulWidget {
  @override
  _UsageContributionState createState() => _UsageContributionState();
}

class _UsageContributionState extends State<UsageContribution> {
  @override
  Widget build(BuildContext context) {
    return Center(child: Consumer<AppProvider>(
      builder: (context, value, child) {
        Map<DateTime, int> datasets = {};
        for (var element in value.data) {
          DateTime node = DateTime.parse(element["node"].toString());
          datasets[node] = element["usage"];
        }
        return Container(
            child: HeatMap(
          datasets: datasets,
          defaultColor: Colors.grey[300],
          colorsets: {1: Colors.blue},
          scrollable: true,
          showColorTip: false,
        ));
      },
    ));
  }
}

class UsageLineChart extends StatefulWidget {
  @override
  _UsageLineChartState createState() => _UsageLineChartState();
}

class _UsageLineChartState extends State<UsageLineChart> {
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(20),
        child: Consumer<AppProvider>(
          builder: (context, value, child) {
            List<FlSpot> spots = [];
            for (var element in value.data) {
              FlSpot spot = FlSpot(element["node"] / 1, element["usage"] / 1);
              spots.add(spot);
            }
            return LineChart(LineChartData(
                lineBarsData: [LineChartBarData(spots: spots)],
                lineTouchData:
                    LineTouchData(touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    List<LineTooltipItem> spots = [];
                    for (var element in touchedSpots) {
                      String hours = (element.y / 3600).toStringAsFixed(2);
                      String minutes = (element.y / 60).toStringAsFixed(2);
                      LineTooltipItem spot = LineTooltipItem(
                          "${element.x.round().toString()} : $hours hours,$minutes minutes",
                          TextStyle(color: Colors.white));
                      spots.add(spot);
                    }
                    return spots;
                  },
                )),
                borderData: FlBorderData(),
                titlesData: FlTitlesData(show: false)));
          },
        ));
  }
}

class EventHandle {
  EventHandle(this.name, this.lastEvent);
  final String name;
  int sum = 0;
  EventUsageInfo lastEvent;

  show(EventUsageInfo event) {
    lastEvent = event;
  }

  hide(EventUsageInfo event) {
    // when app crossing the day. but The end of day isn't handle.
    if (lastEvent.eventType == null) {
      int stamp = int.parse(event.timeStamp!);
      var _today = DateTime.fromMillisecondsSinceEpoch(stamp);
      DateTime _beigin = DateTime(_today.year, _today.month, _today.day);
      int timeDiff = stamp - _beigin.millisecondsSinceEpoch;

      sum += timeDiff;
    }
    // except first event of today is stop. Guarantee pre-event is a starting event.
    if (lastEvent.eventType != null &&
        (lastEvent.eventType == "1" ||
            lastEvent.eventType == "15" ||
            lastEvent.eventType == "19")) {
      int usage = int.parse(event.timeStamp!) - int.parse(lastEvent.timeStamp!);
      sum += usage;
    }
    lastEvent = event;
  }
}

class AppUsageView extends StatefulWidget {
  @override
  _APPUsageViewState createState() => _APPUsageViewState();

  static handleStatsPerDay(List<EventUsageInfo> origin, Map today) {
    Map<String, EventHandle> apps = {};
    List<String> events = [];

    origin.forEach((element) {
      // collect events type
      if (!events.contains(element.eventType!)) events.add(element.eventType!);

      // traverse events   event types : https://developer.android.com/reference/android/app/usage/UsageEvents.Event
      int eventType = int.parse(element.eventType!);
      String packageName = element.packageName!;

      // use EventHandle class to deal timestamps about single app.
      if (!apps.containsKey(packageName))
        apps[packageName] = EventHandle(packageName, EventUsageInfo());
      EventHandle app = apps[packageName]!;

      switch (eventType) {
        case 1: //ACTIVITY_RESUMED
          app.show(element);
          break;
        case 2: //ACTIVITY_PAUSED
          app.hide(element);
          break;
        case 5: //CONFIGURATION_CHANGE
          break;
        case 7: //USER_INTERACTION
          break;
        case 10: //NOTIFICATION_SEEN
          break;
        case 11: //STANDBY_BUCKET_CHANGED
          break;
        case 12: //NOTIFICATION_INTERRUPTION
          break;
        case 15: //SCREEN_INTERACTIVE
          app.show(element);
          break;
        case 16: //SCREEN_NON_INTERACTIVE
          app.hide(element);
          break;
        case 17: //KEYGUARD_SHOWN
          break;
        case 18: //KEYGUARD_HIDDEN
          break;
        case 19: //FOREGROUND_SERVICE_START
          // app.show(element);
          break;
        case 20: //FOREGROUND_SERVICE_STOP
          // app.hide(element);
          break;
        case 23: //ACTIVITY_STOPPED
          // app.hide(element);
          break;
      }
    });

    int sum = 0;

    apps.forEach((key, value) {
      Map tmp = {"name": key, "usage": value.sum / 1000};
      if (value.sum != 0) today["data"].add(tmp);
      if (value.name != "android") sum += value.sum;
    });

    today["data"].add({
      "name": "sum",
      "usage": sum / 1000,
    });
  }

  static Future<List<Map>> getUsage(bool multi) async {
    List<Map> periodUsage = [];
    DateTime now = new DateTime.now();
    DateTime endDate = DateTime(now.year, now.month, now.day);
    DateTime startDate =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: multi ? 10 : 1));

    DateTime cur = startDate;
    while (cur.isBefore(endDate)) {
      cur = cur.add(Duration(days: 1));
      int node =
          int.parse(startDate.toString().substring(0, 10).split('-').join());
      Map today = {"node": node, "data": []};

      List<EventUsageInfo> origin =
          await UsageStats.queryEvents(startDate, cur);
      handleStatsPerDay(origin, today);

      periodUsage.add(today);
      startDate = startDate.add(Duration(days: 1));
    }

    return periodUsage;
  }

  static recordPhoneUsage({bool multi = false}) async {
    var data = await AppUsageView.getUsage(multi);
    dioLara.post("/api/phone/usages", data: data);
  }
}

class _APPUsageViewState extends State<AppUsageView> {
  List _infos = ["waiting"];

  showUsage() async {
    DateTime now = DateTime.now();
    var data = await AppUsageView.getUsage(true);
    var diff = DateTime.now().difference(now);
    print(diff);
    List output = [];
    for (var element in data) {
      output.add(element["node"]);
      for (var app in element["data"]) {
        output.add(app);
      }
    }
    setState(() {
      _infos = output;
    });
  }

  @override
  void initState() {
    showUsage();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: ListView.builder(
          itemCount: _infos.length,
          itemBuilder: ((context, index) {
            return Text(_infos[index].toString());
          })),
    );
  }
}
