import 'dart:convert';
import 'dart:math';
import 'package:blux/usage/timeline.dart';
import 'package:blux/usage/usage_event.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:usage_stats/usage_stats.dart';
import '../utils/network.dart';
import 'package:provider/provider.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';

class UsagePage extends StatelessWidget {
  UsagePage({Key? key}) : super(key: key);

  @override
  Widget build(context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Phone Usage Stats"),
          actions: [
            IconButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: ((context) => EventForm()))),
                icon: Icon(Icons.search))
          ],
        ),
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
  late FixedExtentScrollController scrollController;
  int selectedApp = 0;

  Widget showApps(context) {
    List<Widget> apps = [];

    app.apps.forEach((element) {
      var name = (element["name"] != null && element["name"] != "")
          ? element["name"]
          : element["package_name"];
      apps.add(Center(child: Text(name)));
    });
    return CupertinoActionSheet(
      actions: [
        SizedBox(
            height: 400,
            child: CupertinoPicker(
                scrollController: scrollController,
                itemExtent: 64,
                onSelectedItemChanged: (v) => selectedApp = v,
                children: apps)),
        Row(
          children: [
            Expanded(
              child: CupertinoActionSheetAction(
                  onPressed: () async {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel", style: TextStyle(color: Colors.red))),
            ),
            Expanded(
              child: CupertinoActionSheetAction(
                  onPressed: () async {
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
                  child: Text("Confirm")),
            )
          ],
        )
      ],
    );
  }

  @override
  void initState() {
    dioLara.get("/api/phone/apps").then((value) async {
      var data = jsonDecode(value.data);
      List _apps = [];
      int sumId = 0;
      for (var element in data["data"]) {
        if (element["package_name"] == "sum") {
          sumId = element["id"];
        } else {
          // generate map of apps
          app.appMap[element["id"]] =
              element["name"] != null && element["name"] != ''
                  ? element["name"]
                  : element['package_name'];
        }
        if (element["display"] == 1) _apps.add(element);
      }
      app.appId = sumId;
      var usageStats = await app.getData();
      setState(() {
        app.apps = _apps;
        app.data = usageStats;
        loading = false;
      });
    });

    super.initState();

    scrollController = FixedExtentScrollController(initialItem: selectedApp);
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  void _watchDate(FlTouchEvent event, LineTouchResponse? response) {
    if (event is FlTapUpEvent) {
      var index = response!.lineBarSpots![0].spotIndex;
      String node = app.data[index]['node'];

      setState(() {
        app.current = node;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Provider<AppProvider>.value(
        value: app,
        child: loading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  UsageTop(),
                  Expanded(
                      child:
                          Provider.value(value: this, child: UsageLineChart())),
                  SizedBox(
                      height: 80,
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(left: 30, right: 30),
                              child: ElevatedButton(
                                  onPressed: () {
                                    scrollController.dispose();
                                    scrollController =
                                        FixedExtentScrollController(
                                            initialItem: selectedApp);
                                    showCupertinoModalPopup(
                                        context: context, builder: showApps);
                                  },
                                  child: Text(app.name)),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(left: 30, right: 30),
                              child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: ((context) =>
                                              UsageTimeLine()))),
                                  child: Text("Detail")),
                            ),
                          )
                        ],
                      ))
                ],
              ));
  }
}

class AppProvider {
  AppProvider();
  String name = "sum";
  int appId = 0;
  List apps = [];
  Map<int, String> appMap = {};
  List data = [];
  String current = DateTime.now()
      .subtract(Duration(days: 1))
      .toIso8601String()
      .substring(0, 10);
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
          datasets[node] = (element["usage"] * 0.01).round();
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

class UsageTop extends StatefulWidget {
  UsageTop({Key? key}) : super(key: key);

  @override
  State<UsageTop> createState() => _UsageTopState();
}

class _UsageTopState extends State<UsageTop> {
  String _date = '';
  List _data = [];
  int _highlight = 0;

  _queryTop() {
    laravel.get("/phone/usages/top/$_date").then(
      (value) {
        var result = value.data["data"];
        var apps = context.read<AppProvider>().appMap;
        for (var element in result) {
          element["name"] = apps[element['appid']];
        }
        setState(() => _data = result);
      },
    );
  }

  PieChartData _pieData() {
    List<PieChartSectionData> sections = [];
    // high light the first element that largest usages.
    if(_data.length > 0) _highlight = _data[0]['id'];
    for (var element in _data) {
      var color = Color.fromARGB(255, Random().nextInt(255),
          Random().nextInt(255), Random().nextInt(255));
      PieChartSectionData tmp = PieChartSectionData(
          value: (element["usage"] / 60).ceil(), color: color);
      element['color'] = color;
      sections.add(tmp);
    }
    return PieChartData(sections: sections);
  }

  Widget _top10() {
    List<Widget> left = [];
    List<Widget> right = [];
    int i = 0;
    for (var element in _data) {
      String name = element['name'] != null && element['name'] != ''
          ? element['name']
          : element['package_name'];
      bool highlight = _highlight == element['id'] ? true : false;
      if (i < 5) {
        left.add(AppLabel(name, element["color"], highlight));
      } else {
        right.add(AppLabel(name, element["color"], highlight));
      }
      i++;
    }
    Widget row = Row(
      children: [
        Container(child: Column(children: left)),
        Container(child: Column(children: right))
      ],
    );

    return row;
  }

  @override
  Widget build(BuildContext context) {
    final date = context.watch<AppProvider>().current;
    if (_date != date) {
      _date = date;
      _queryTop();
    }
    return Container(
        height: 220,
        child: Consumer<AppProvider>(
          builder: ((context, value, child) {
            return Column(
              children: [
                Text(value.current.toString()),
                Row(
                  children: [
                    Container(
                        width: 160,
                        height: 160,
                        margin: EdgeInsets.all(20),
                        child:
                            _data != [] ? PieChart(_pieData()) : Container()),
                    Container(
                      child: _top10(),
                    )
                  ],
                )
              ],
            );
          }),
        ));
  }
}

class AppLabel extends StatelessWidget {
  const AppLabel(this.name, this.color, this.highlight, {Key? key})
      : super(key: key);
  final String name;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 30,
        width: 130,
        margin: EdgeInsets.only(bottom: 2, right: 2),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.all(Radius.circular(10))),
        child: Row(children: [
          Container(width: highlight ? 20 : 10, color: color),
          Expanded(
              child: Text(
            name,
            style: TextStyle(color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ))
        ]));
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
        padding: EdgeInsets.only(left: 10, top: 20, right: 20),
        child: Consumer<AppProvider>(
          builder: (context, value, child) {
            if (value.data.length == 0) return LineChart(LineChartData());
            List<FlSpot> spots = [];
            double maxY = 0;
            double minY = double.infinity;
            value.data.sort((e1, e2) => DateTime.parse(e1["node"])
                .compareTo(DateTime.parse(e2["node"])));
            int i = 0;
            for (var element in value.data) {
              double _usage = element["usage"] / 1;
              if (_usage > maxY) maxY = _usage;
              if (_usage < minY) minY = _usage;
              FlSpot spot = FlSpot(i / 1, _usage);
              spots.add(spot);
              i++;
            }
            return LineChart(
              LineChartData(
                  minY: minY * 0.8,
                  maxY: maxY * 1.05,
                  lineBarsData: [
                    LineChartBarData(
                        spots: spots,
                        color: Colors.redAccent,
                        dotData: FlDotData(
                          getDotPainter: (p0, p1, p2, p3) {
                            return FlDotCirclePainter(
                                strokeColor: Colors.redAccent,
                                color: Colors.white,
                                radius: 3);
                          },
                        ))
                  ],
                  lineTouchData: LineTouchData(
                      touchCallback: context.read<_PhoneStatState>()._watchDate,
                      touchTooltipData: LineTouchTooltipData(
                        fitInsideHorizontally: true,
                        getTooltipItems: (touchedSpots) {
                          List<LineTooltipItem> spots = [];
                          for (var element in touchedSpots) {
                            String hours =
                                (element.y / 3600).toStringAsFixed(2);
                            String minutes =
                                (element.y / 60).toStringAsFixed(2);
                            LineTooltipItem spot = LineTooltipItem(
                                "${value.data[element.x.round()]["node"]} \n $hours hours \n $minutes minutes",
                                TextStyle(color: Colors.white));
                            spots.add(spot);
                          }
                          return spots;
                        },
                      )),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                      rightTitles: AxisTitles(),
                      topTitles: AxisTitles(),
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                        interval: 3600,
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          String _hour = (value / 3600).round().toString();
                          if (value % 3600 == 0)
                            return Center(child: Text(_hour));
                          return Container();
                        },
                      )),
                      bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (x, meta) {
                                String _date = value.data[x.round()]["node"];
                                _date = _date.substring(_date.length - 5);
                                return Transform.rotate(
                                    angle: -0.5,
                                    child: Center(child: Text(_date)));
                              })))),
              swapAnimationDuration: Duration(milliseconds: 500),
            );
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
    //   will change the way to handle event that crossing day.
    //    maybe using continuous events, manual divide days.

    // if (lastEvent.eventType == null) {
    //   int stamp = int.parse(event.timeStamp!);
    //   var _today = DateTime.fromMillisecondsSinceEpoch(stamp);
    //   DateTime _beigin = DateTime(_today.year, _today.month, _today.day);
    //   int timeDiff = stamp - _beigin.millisecondsSinceEpoch;
    //   sum += timeDiff;
    // }
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

    origin.forEach((element) {
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

    apps.forEach((key, value) {
      Map tmp = {"name": key, "usage": value.sum / 1000};
      if (value.sum != 0) today["data"].add(tmp);
    });
  }

  static Future<List<Map>> getUsage(bool multi) async {
    List<Map> periodUsage = [];
    DateTime now = new DateTime.now();
    DateTime endDate = DateTime(now.year, now.month, now.day);
    DateTime startDate = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: multi ? 9 : 1));

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
    if (UniversalPlatform.isAndroid) {
      if (await UsageStats.checkUsagePermission() ?? false) {
        var data = await AppUsageView.getUsage(multi);
        dioLara
            .post("/api/phone/usages", data: data)
            .then((value) => print(value.data));
      }
      UsageStats.grantUsagePermission();
    }
  }
}

class _APPUsageViewState extends State<AppUsageView> {
  List _infos = ["waiting"];

  showUsage() async {
    if (!(await UsageStats.checkUsagePermission() ?? false))
      UsageStats.grantUsagePermission();
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
