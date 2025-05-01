import 'dart:convert';
import 'dart:math';
import 'package:blux/usage/timeline.dart';
import 'package:blux/usage/usage_event.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/network.dart';
import 'package:provider/provider.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';

class UsagePage extends StatelessWidget {
  const UsagePage({super.key});

  @override
  Widget build(context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Phone Usage Stats"),
          actions: [
            IconButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: ((context) => EventForm()))),
                icon: const Icon(Icons.search))
          ],
        ),
        body: Container(child: PhoneStat()));
  }
}

class PhoneStat extends StatefulWidget {
  const PhoneStat({super.key});

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

    for (var element in app.apps) {
      var name = (element["name"] != null && element["name"] != "")
          ? element["name"]
          : element["package_name"];
      apps.add(Center(child: Text(name)));
    }
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
                  child: const Text("Cancel", style: TextStyle(color: Colors.red))),
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
                  child: const Text("Confirm")),
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
      List apps = [];
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
        if (element["display"] == 1) apps.add(element);
      }
      app.appId = sumId;
      var usageStats = await app.getData();
      setState(() {
        app.apps = apps;
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
            ? const Center(child: CircularProgressIndicator())
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
                                              const UsageTimeLine()))),
                                  child: const Text("Detail")),
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
      .subtract(const Duration(days: 1))
      .toIso8601String()
      .substring(0, 10);
  Future<List> getData() async {
    var response = await dioLara.get("/api/phone/usages/$appId");
    var data = jsonDecode(response.data);
    return data["data"];
  }
}

class UsageContribution extends StatefulWidget {
  const UsageContribution({super.key});

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
          colorsets: const {1: Colors.blue},
          scrollable: true,
          showColorTip: false,
        ));
      },
    ));
  }
}

class UsageTop extends StatefulWidget {
  const UsageTop({super.key});

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

        setState(() {
          _highlight = result[0]
              ['id']; // high light the first element that largest usages.
          _data = result;
        });
      },
    );
  }

  PieChartData _pieData() {
    List<PieChartSectionData> sections = [];

    for (var element in _data) {
      var color;
      element as Map;
      if (!element.containsKey("color")) {
        color = Color.fromARGB(255, Random().nextInt(255),
            Random().nextInt(255), Random().nextInt(255));
        element['color'] = color;
      } else {
        color = element['color'];
      }

      double value = (element["usage"] / 60).roundToDouble();
      PieChartSectionData tmp = PieChartSectionData(
          value: value,
          color: color,
          title: value.round().toString(),
          titleStyle: const TextStyle(shadows: [
            Shadow(color: Colors.white, blurRadius: 1),
            Shadow(color: Colors.white, blurRadius: 1),
            Shadow(color: Colors.white, blurRadius: 1),
          ]),
          radius: _highlight == element['id'] ? 80 : 66);

      sections.add(tmp);
    }
    return PieChartData(
        sections: sections,
        sectionsSpace: 6,
        centerSpaceRadius: 15,
        pieTouchData: PieTouchData(
          touchCallback: (p0, p1) {
            if (p0 is FlTapUpEvent && p1 != null) {
              final index = p1.touchedSection!.touchedSectionIndex;
              if (index >= 0 && _data[index] != null) {
                setState(() => _highlight = _data[index]['id']);
              }
            }
          },
        ));
  }

  Widget _top10() {
    List<Widget> list = [];

    for (var element in _data) {
      String name = element['name'] != null && element['name'] != ''
          ? element['name']
          : element['package_name'];
      bool highlight = _highlight == element['id'] ? true : false;
      list.add(AppLabel(name, element["color"], highlight));
    }
    return ListView(
      children: list,
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = context.watch<AppProvider>().current;
    if (_date != date) {
      _date = date;
      _queryTop();
    }
    return SizedBox(
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
                        margin: const EdgeInsets.all(20),
                        child:
                            _data != [] ? PieChart(_pieData()) : Container()),
                    SizedBox(
                      height: 160,
                      width: 160,
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
  const AppLabel(this.name, this.color, this.highlight, {super.key});
  final String name;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 30,
        width: 130,
        margin: const EdgeInsets.only(bottom: 2, right: 2),
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.all(Radius.circular(10))),
        child: Row(children: [
          Container(width: highlight ? 20 : 10, color: color),
          Expanded(
              child: Text(
            name,
            style: const TextStyle(color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ))
        ]));
  }
}

class UsageLineChart extends StatefulWidget {
  const UsageLineChart({super.key});

  @override
  _UsageLineChartState createState() => _UsageLineChartState();
}

class _UsageLineChartState extends State<UsageLineChart> {
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.only(left: 10, top: 20, right: 20),
        child: Consumer<AppProvider>(
          builder: (context, value, child) {
            if (value.data.isEmpty) return LineChart(LineChartData());
            List<FlSpot> spots = [];
            double maxY = 0;
            double minY = double.infinity;
            value.data.sort((e1, e2) => DateTime.parse(e1["node"])
                .compareTo(DateTime.parse(e2["node"])));
            value.data = value.data.reversed.toList();
            int i = 0;
            for (var element in value.data) {
              double usage = element["usage"] / 1;
              if (usage > maxY) maxY = usage;
              if (usage < minY) minY = usage;
              FlSpot spot = FlSpot(i / 1, usage);
              spots.add(spot);
              i++;
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                width: value.data.length * 5,
                padding: const EdgeInsets.only(right: 50),
                child: LineChart(
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
                          touchCallback:
                              context.read<_PhoneStatState>()._watchDate,
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
                                    const TextStyle(color: Colors.white));
                                spots.add(spot);
                              }
                              return spots;
                            },
                          )),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(),
                          topTitles: const AxisTitles(),
                          leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                            interval: 3600,
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              String hour = (value / 3600).round().toString();
                              if (value % 3600 == 0) {
                                return Center(child: Text(hour));
                              }
                              return Container();
                            },
                          )),
                          bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (x, meta) {
                                    String date =
                                        value.data[x.round()]["node"];
                                    date = date.substring(date.length - 5);
                                    return Transform.rotate(
                                        angle: -0.5,
                                        child: Center(child: Text(date)));
                                  })))),
                  duration: const Duration(milliseconds: 500),
                ),
              ),
            );
          },
        ));
  }
}
