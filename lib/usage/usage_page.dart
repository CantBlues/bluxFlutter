import 'dart:math';
import 'package:blux/kitt/theme.dart';
import 'package:blux/kitt/widgets.dart';
import 'package:blux/local/local_db.dart';
import 'package:blux/usage/timeline.dart';
import 'package:blux/usage/usage_event.dart';
import 'package:blux/usage/usage_utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';

/// Screen-time analytics, fully offline: every series comes from the
/// local usage_daily table that the collector writes on this phone.
class UsagePage extends StatelessWidget {
  const UsagePage({super.key});

  @override
  Widget build(context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("屏幕使用统计"),
          actions: [
            IconButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: ((context) => const EventForm()))),
                icon: const Icon(Icons.query_stats))
          ],
        ),
        body: const GridBackdrop(child: SafeArea(child: PhoneStat())));
  }
}

class AppModel {
  AppModel();
  String name = "sum";
  String? pkg; // null = summed over displayed apps
  List<Map<String, Object?>> apps = [];
  Map<String, String> appMap = {}; // pkg -> display name
  List data = [];
  String current =
      LocalDb.key(DateTime.now().subtract(const Duration(days: 1)));

  Future<List> getData() async {
    final rows = await UsageRepo.dailySeries(pkg: pkg);
    return rows;
  }
}

class PhoneStat extends StatefulWidget {
  const PhoneStat({super.key});

  @override
  _PhoneStatState createState() => _PhoneStatState();
}

class _PhoneStatState extends State<PhoneStat> {
  AppModel app = AppModel();
  bool loading = true;
  late FixedExtentScrollController scrollController;
  int selectedApp = 0;

  String appName(Map<String, Object?> e) {
    final n = e['name'];
    return (n != null && n.toString().isNotEmpty) ? n.toString() : e['pkg'].toString();
  }

  Widget showApps(BuildContext context) {
    List<Widget> apps = [Center(child: Text("全部合计", style: KittStyle.body(color: KittColors.red)))];
    for (var element in app.apps) {
      apps.add(Center(child: Text(appName(element))));
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("取消", style: TextStyle(color: KittColors.red))),
            ),
            Expanded(
              child: CupertinoActionSheetAction(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    if (selectedApp == 0) {
                      app.pkg = null;
                      app.name = "sum";
                    } else {
                      final cur = app.apps[selectedApp - 1];
                      app.pkg = cur['pkg'] as String?;
                      app.name = appName(cur);
                    }
                    var data = await app.getData();
                    setState(() => app.data = data);
                  },
                  child: const Text("确认")),
            )
          ],
        )
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    scrollController = FixedExtentScrollController(initialItem: selectedApp);
    _load();
    // opportunistic top-up of history while offline-capable
    Future.microtask(() => recordPhoneUsage());
  }

  _load() async {
    final apps = await UsageRepo.apps(displayOnly: true);
    final map = <String, String>{
      for (final e in apps) e['pkg'] as String: appName(e)
    };
    var data = await app.getData();
    if (!mounted) return;
    setState(() {
      app.apps = apps;
      app.appMap = map;
      app.data = data;
      loading = false;
    });
  }

  void _watchDate(FlTouchEvent event, LineTouchResponse? response) {
    if (event is FlTapUpEvent && response != null && response.lineBarSpots != null) {
      var index = response.lineBarSpots![0].spotIndex;
      String node = app.data[index]['node'];
      setState(() => app.current = node);
    }
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              UsageTop(appMap: app.appMap, date: app.current),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: KittPanel(
                          padding: EdgeInsets.zero,
                          title: "趋势 // ${app.name}",
                          child: UsageLineChart(
                              data: app.data,
                              onPointTap: _watchDate,
                              selected: app.current)))),
              SizedBox(
                  height: 84,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 30, right: 10),
                          child: ElevatedButton(
                              onPressed: () {
                                scrollController.dispose();
                                scrollController = FixedExtentScrollController(
                                    initialItem: selectedApp);
                                showCupertinoModalPopup(
                                    context: context,
                                    builder: showApps);
                              },
                              child: Text(app.name.toUpperCase())),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 30),
                          child: ElevatedButton(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: ((context) =>
                                          const UsageTimeLine()))),
                              child: const Text("时间线")),
                        ),
                      ),
                    ],
                  ))
            ],
          );
  }
}

/// Heat contribution of total screen time.
class UsageContribution extends StatefulWidget {
  const UsageContribution({super.key});

  @override
  _UsageContributionState createState() => _UsageContributionState();
}

class _UsageContributionState extends State<UsageContribution> {
  Map<String, int>? data;

  @override
  void initState() {
    super.initState();
    UsageRepo.heatmap().then((rows) {
      setState(() {
        data = {for (final r in rows) r['date'] as String: ((r['s'] as num).toInt())};
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) return const Center(child: CircularProgressIndicator());
    Map<DateTime, int> datasets = {};
    data!.forEach((k, v) => datasets[LocalDb.day(k)] = min(4, max(1, v ~/ 3600)));
    return SizedBox(
        height: 220,
        child: HeatMap(
          datasets: datasets,
          defaultColor: KittColors.panelSoft,
          textColor: KittColors.textDim,
          scrollable: true,
          showColorTip: false,
          colorsets: const {
            1: KittColors.redDeep,
            2: KittColors.red,
            3: KittColors.redBright,
            4: Color(0xFFFF9A8D),
          },
        ));
  }
}

/// Top-10 pie for the selected day, straight out of usage_daily.
class UsageTop extends StatefulWidget {
  const UsageTop({super.key, required this.appMap, required this.date});
  final Map<String, String> appMap;
  final String date;

  @override
  State<UsageTop> createState() => _UsageTopState();
}

class _UsageTopState extends State<UsageTop> {
  String _date = '';
  List _data = [];
  int _highlight = -1;

  _queryTop() async {
    final result = await UsageRepo.topByDate(widget.date);
    for (var i = 0; i < result.length; i++) {
      result[i]['display'] =
          widget.appMap[result[i]['pkg']] ?? result[i]['pkg'];
      result[i]['id'] = i;
      result[i]['color'] = KittColors.chartAt(i);
    }
    if (!mounted) return;
    setState(() {
      _highlight = result.isEmpty ? -1 : result[0]['id'] as int;
      _data = result;
    });
  }

  PieChartData _pieData() {
    List<PieChartSectionData> sections = [];

    for (var element in _data) {
      double value = ((element["usage"] as num) / 60).roundToDouble();
      PieChartSectionData tmp = PieChartSectionData(
          value: value,
          color: element['color'],
          title: value.round().toString(),
          titleStyle: const TextStyle(
              fontSize: 10, fontFamily: KittStyle.mono, color: Colors.black),
          radius: _highlight == element['id'] ? 66 : 52);

      sections.add(tmp);
    }
    return PieChartData(
        sections: sections,
        sectionsSpace: 5,
        centerSpaceRadius: 14,
        pieTouchData: PieTouchData(
          touchCallback: (p0, p1) {
            if (p0 is FlTapUpEvent && p1 != null) {
              final index = p1.touchedSection?.touchedSectionIndex ?? -1;
              if (index >= 0 && _data[index] != null) {
                setState(() => _highlight = _data[index]['id'] as int);
              }
            }
          },
        ));
  }

  Widget _top10() {
    List<Widget> list = [];

    for (var element in _data) {
      bool highlight = _highlight == element['id'];
      list.add(AppLabel(element['display'], element["color"], highlight));
    }
    return ListView(shrinkWrap: true, children: list);
  }

  @override
  Widget build(BuildContext context) {
    if (_date != widget.date) {
      _date = widget.date;
      _queryTop();
    }
    return SizedBox(
        height: 230,
        child: KittPanel(
            accent: KittColors.amber,
            title: "当日Top // ${widget.date}",
            child: LayoutBuilder(builder: (context, c) {
              final pw = ((c.maxWidth - 14) / 2).clamp(100.0, 160.0);
              return Row(
                children: [
                  SizedBox(
                      width: pw,
                      height: pw,
                      child: _data.isNotEmpty
                          ? PieChart(_pieData())
                          : Center(
                              child: Text("暂无数据",
                                  style: KittStyle.label(size: 12))),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(height: pw, width: pw, child: _top10()),
                ],
              );
            })));
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
        height: 28,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 3),
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
            color: KittColors.panelSoft,
            borderRadius: BorderRadius.all(Radius.circular(4))),
        child: Row(children: [
          Container(width: highlight ? 18 : 8, color: color),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    name,
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: KittStyle.mono,
                        color: highlight ? KittColors.text : KittColors.textDim),
                    overflow: TextOverflow.ellipsis,
                  )))
        ]));
  }
}

class UsageLineChart extends StatelessWidget {
  const UsageLineChart(
      {super.key, required this.data, required this.onPointTap, required this.selected});
  final List data;
  final void Function(FlTouchEvent, LineTouchResponse?) onPointTap;
  final String selected;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
          height: 200,
          child: Center(
              child: Text(
                  "暂无曲线。\n授予使用权限后自动采集。",
                  style: KittStyle.label(color: KittColors.textDim))));
    }
    final points = List.from(data)
      ..sort((e1, e2) => DateTime.parse(e1["node"]).compareTo(DateTime.parse(e2["node"])));
    List<FlSpot> spots = [];
    double maxY = 0;
    double minY = double.infinity;
    int i = 0;
    for (var element in points) {
      double usage = (element["usage"] as num).toDouble();
      if (usage > maxY) maxY = usage;
      if (usage < minY) minY = usage;
      spots.add(FlSpot(i.toDouble(), usage));
      i++;
    }
    return SizedBox(
      height: 230,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          width: max(320, points.length * 5.0),
          padding: const EdgeInsets.only(right: 50, top: 10),
          child: LineChart(
            LineChartData(
                minY: (minY * 0.8).clamp(0, double.infinity).toDouble(),
                maxY: maxY * 1.1 + 60,
                lineBarsData: [
                  LineChartBarData(
                      spots: spots,
                      color: KittColors.red,
                      barWidth: 2,
                      isCurved: true,
                      belowBarData: BarAreaData(
                          show: true, color: KittColors.red.withOpacity(.08)),
                      dotData: FlDotData(
                        getDotPainter: (p0, p1, p2, p3) {
                          return FlDotCirclePainter(
                              strokeColor: KittColors.red,
                              color: KittColors.bg,
                              radius: 2.5);
                        },
                      ))
                ],
                lineTouchData: LineTouchData(
                    touchCallback: (event, response) => onPointTap(event, response),
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => KittColors.panelSoft,
                      getTooltipItems: (touchedSpots) {
                        List<LineTooltipItem> spots = [];
                        for (var element in touchedSpots) {
                          String hours = (element.y / 3600).toStringAsFixed(2);
                          String minutes = (element.y / 60).toStringAsFixed(1);
                          LineTooltipItem spot = LineTooltipItem(
                              "${points[element.x.round()]["node"]} \n ${hours}h  ${minutes}min",
                              TextStyle(
                                  color: points[element.x.round()]["node"] == selected
                                      ? KittColors.redBright
                                      : KittColors.text,
                                  fontFamily: KittStyle.mono,
                                  fontSize: 11));
                          spots.add(spot);
                        }
                        return spots;
                      },
                    )),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: KittColors.grid, strokeWidth: .5)),
                titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (value, meta) {
                        String hour = (value / 3600).round().toString();
                        if (value % 3600 == 0) {
                          return Center(
                              child: Text(hour,
                                  style: const TextStyle(
                                      fontSize: 11, fontFamily: KittStyle.mono)));
                        }
                        return Container();
                      },
                    )),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            interval: max(1, (points.length / 6).ceilToDouble()),
                            getTitlesWidget: (x, meta) {
                              final idx = x.round();
                              if (idx >= points.length) return Container();
                              String date = points[idx]["node"];
                              date = date.substring(date.length - 5);
                              return Transform.rotate(
                                  angle: -0.5,
                                  child: Center(
                                      child: Text(date,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontFamily: KittStyle.mono))));
                            })))),
            duration: const Duration(milliseconds: 500),
          ),
        ),
      ),
    );
  }
}
