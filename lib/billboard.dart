import 'dart:math';
import 'dart:typed_data';
import 'package:blux/kitt/theme.dart';
import 'package:blux/kitt/widgets.dart';
import 'package:blux/local/local_db.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';

/// Full-screen analytics: contributions heatmap, month comparison,
/// the body/soul seesaw and exercise cooldown list — all computed from
/// the local database, works without any server.
class Billboard extends StatefulWidget {
  const Billboard({super.key});

  @override
  State<StatefulWidget> createState() => _BillboardState();
}

class _BillboardState extends State<Billboard> {
  String _type = "Sum";
  bool _loading = true;
  List<TaskType> _typeMenu = [];
  Map<String, int> _contributionData = {};
  Map<String, List<int>> _monthCompare = {};
  List<Map<String, dynamic>> _overdue = [];

  getContributionData(String type) async {
    final data = type == "Sum"
        ? await TaskRepo.contributions()
        : await TaskRepo.contributionsFor(type);
    setState(() {
      _contributionData = data;
      _type = type;
    });
  }

  _load() async {
    final types = await TaskRepo.types();
    final compare = await TaskRepo.monthCompare();
    final overdue = await TaskRepo.overdueBody();
    final contribution = await TaskRepo.contributions();
    if (!mounted) return;
    setState(() {
      _typeMenu = types;
      _monthCompare = compare;
      _overdue = overdue;
      _contributionData = contribution;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Text("数据分析"),
            actions: [
              PopupMenuButton<String>(
                  offset: const Offset(0, 50),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(_type == "Sum" ? "全部" : _type,
                          style: KittStyle.label(size: 13, color: KittColors.amber, spacing: 1))),
                  itemBuilder: (context) {
                    List<PopupMenuEntry<String>> menus = [
                      const PopupMenuItem(value: "Sum", child: Text("全部合计")),
                      for (var element in _typeMenu)
                        PopupMenuItem(value: element.name, child: Text(element.name)),
                    ];
                    return menus;
                  },
                  onSelected: getContributionData)
            ]),
        body: GridBackdrop(
            child: SafeArea(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(14),
                        children: [
                          KittPanel(
                              title: "贡献热力 // ${_type == "Sum" ? "全部" : _type}",
                              child: ContributionView(_type, _contributionData)),
                          const SizedBox(height: 12),
                          KittPanel(
                              title: "本月对比",
                              child: BarChartView(_monthCompare)),
                          const SizedBox(height: 12),
                          KittPanel(
                              title: "身心灵平衡",
                              accent: KittColors.amber,
                              child: PercentageView(_monthCompare, _typeMenu)),
                          const SizedBox(height: 12),
                          KittPanel(
                              title: "冷却提醒",
                              accent: KittColors.cyan,
                              child: OverdueList(_overdue)),
                        ]))));
  }
}

class ContributionView extends StatelessWidget {
  const ContributionView(this.name, this.data, {super.key});
  final String name;
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    Map<DateTime, int> datasets = {};
    data.forEach((k, v) {
      datasets[LocalDb.day(k)] = v;
    });

    return SizedBox(
        height: 220,
        child: Center(
            child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: HeatMap(
                    scrollable: true,
                    datasets: datasets,
                    showColorTip: false,
                    defaultColor: KittColors.panelSoft,
                    textColor: KittColors.textDim,
                    colorsets: const {
                      1: KittColors.redDeep,
                      2: KittColors.red,
                      4: KittColors.redBright,
                    }))));
  }
}

class BarChartView extends StatelessWidget {
  const BarChartView(this.data, {super.key});
  final Map<String, List<int>> data;

  BarChartGroupData makeGroupData(int x, double y1, double y2) {
    return BarChartGroupData(barsSpace: 4, x: x, barRods: [
      BarChartRodData(toY: y1, color: KittColors.red, width: 10),
      BarChartRodData(toY: y2, color: KittColors.amber, width: 10),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    List<BarChartGroupData> items = [];
    List<String> name = [];
    int i = 0;
    data.forEach((key, value) {
      items.add(makeGroupData(i, value[0].toDouble(), value.length == 2 ? value[1].toDouble() : 0));
      name.add(key);
      i++;
    });

    return SizedBox(
        height: 240,
        child: Padding(
            padding: const EdgeInsets.only(top: 10, right: 10),
            child: Row(children: [
              RotatedBox(
                  quarterTurns: 3,
                  child: Text("红=本月 琥珀=上月",
                      style: KittStyle.label(size: 12, spacing: 1))),
              const SizedBox(width: 6),
              Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text("暂无数据",
                              style: KittStyle.label(color: KittColors.textDim)))
                      : BarChart(BarChartData(
                          maxY: (data.values
                                      .map((e) => e.reduce(max))
                                      .fold(0, max) +
                                  1)
                              .toDouble(),
                          minY: 0,
                          barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                  getTooltipColor: (_) => KittColors.panelSoft,
                                  getTooltipItem: (group, gi, rod, ri) =>
                                      BarTooltipItem(
                                          "${name[group.x]}: ${rod.toY.toInt()}\n",
                                          const TextStyle(
                                              color: KittColors.text,
                                              fontFamily: KittStyle.mono,
                                              fontSize: 12)))),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 56,
                                    getTitlesWidget: (num, TitleMeta a) {
                                      return Transform.rotate(
                                          angle: -0.8,
                                          child: Center(
                                              child: Text(name[num.round()],
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontFamily: KittStyle.mono,
                                                      color: KittColors.textDim))));
                                    })),
                            leftTitles: const AxisTitles(),
                            rightTitles: const AxisTitles(),
                            topTitles: const AxisTitles(),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: items,
                          gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (v) =>
                                  FlLine(color: KittColors.grid, strokeWidth: .5)),
                        ))),
            ])));
  }
}

class PercentageView extends StatelessWidget {
  const PercentageView(this.data, this.types, {super.key});

  final Map<String, List<int>> data;
  final List<TaskType> types;

  @override
  Widget build(BuildContext context) {
    final bodyNames = types.where((t) => t.classify == 'body').map((t) => t.name).toSet();
    final soulMap = {for (final t in types.where((t) => t.classify == 'soul')) t.name: t.weight};
    final stepsMap = {for (final t in types.where((t) => t.classify == 'steps')) t.name: t.weight};

    List<Map<String, dynamic>> pieData = [];
    int soulNum = 0;
    int stepsNum = 0;
    data.forEach((name, value) {
      if (bodyNames.contains(name)) {
        pieData.add({"name": name, "times": value[0]});
      }
      if (soulMap.containsKey(name)) soulNum += value[0] * soulMap[name]!;
      if (stepsMap.containsKey(name)) stepsNum += value[0] * stepsMap[name]!;
    });

    int drop = stepsNum - soulNum;
    double angle = drop / 50;
    return SizedBox(
        height: 220,
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
                child: LayoutBuilder(builder: (context, c) {
              final paintSize = min(c.maxWidth, c.maxHeight) - 16;
              return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size.square(paintSize),
                        painter: Seesaw(angle),
                      ),
                      Positioned(
                          top: 4,
                          child: Text("心灵$soulNum / 步数$stepsNum",
                              style: KittStyle.label(
                                  size: 12, color: KittColors.amber, spacing: 0)),
                          width: c.maxWidth),
                    ],
                  ));
            })),
            Expanded(
                child: Center(
                    child: PhysicalPie(pieData.map((e) => e).toList(), false))),
          ],
        ));
  }
}

class Seesaw extends CustomPainter {
  const Seesaw(this.angle);
  final double angle;
  Float64List transit(double dx, double dy) {
    return Float64List.fromList(
        [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1]);
  }

  Float64List rotate(num x) {
    return Float64List.fromList(
        [cos(x), sin(x), 0, 0, -sin(x), cos(x), 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    Offset middle = Offset(size.width / 2, size.height / 2);
    Offset peak = middle.translate(0, 30);
    Offset left = peak.translate(-10, 20);
    Offset right = peak.translate(10, 20);
    Paint painter = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.fill
      ..color = KittColors.red
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    Paint painterPlank = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.fill
      ..color = KittColors.amber
      ..strokeWidth = 4;
    Path tri = Path()..moveTo(peak.dx, peak.dy);
    tri.lineTo(left.dx, left.dy);
    tri.lineTo(right.dx, right.dy);
    double width = size.width / 2.5;

    Path plank = Path()..moveTo(peak.dx - width, peak.dy - 10);
    plank.lineTo(peak.dx - width, peak.dy);
    plank.lineTo(peak.dx + width, peak.dy);
    plank.lineTo(peak.dx + width, peak.dy - 10);

    double degree = angle;
    plank = plank.transform(rotate(degree));
    double afterX = peak.dx * cos(degree) - peak.dy * sin(degree);
    double afterY = (peak.dx) * sin(degree) + peak.dy * cos(degree);
    plank = plank.transform(transit(peak.dx - afterX, peak.dy - afterY));

    canvas.drawPath(tri, painter);
    canvas.drawPath(plank, painterPlank);
  }

  @override
  bool shouldRepaint(covariant Seesaw oldDelegate) {
    return oldDelegate.angle != angle;
  }
}

class PhysicalPie extends StatelessWidget {
  const PhysicalPie(this.data, this.big, {super.key});
  final List data;
  final bool big;

  @override
  Widget build(BuildContext context) {
    List<PieChartSectionData> pieData = [];
    num pieSum = 0;
    for (var element in data.asMap().entries) {
      pieSum += element.value["times"];
      PieChartSectionData part = PieChartSectionData(
          radius: big ? 100 : 55,
          title: "${element.value["name"]}:${element.value["times"]}",
          titleStyle: TextStyle(
              fontSize: big ? 15 : 12,
              fontFamily: KittStyle.mono,
              color: Colors.black),
          value: (element.value["times"] as num).toDouble(),
          color: KittColors.chartAt(element.key));
      pieData.add(part);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sections: pieData,
            sectionsSpace: 6,
          ),
          swapAnimationDuration: const Duration(seconds: 1),
        ),
        Text(
          pieSum.toString(),
          style: KittStyle.glow(size: 26, color: KittColors.text),
        )
      ],
    );
  }
}

class OverdueList extends StatelessWidget {
  const OverdueList(this.overdue, {super.key});
  final List<Map<String, dynamic>> overdue;

  @override
  Widget build(BuildContext context) {
    final rows = overdue.where((e) => (e['days'] as int) >= 1).toList()
      ..sort((a, b) => b['days'].compareTo(a['days']));
    if (rows.isEmpty) {
      return Text("全部状态新鲜", style: KittStyle.label(color: KittColors.green, spacing: 1));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in rows)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Text("⚠", style: TextStyle(color: _cool(e['days'] as int))),
                  const SizedBox(width: 8),
                  Text("${e['name']}",
                      style: KittStyle.body(size: 13, color: _cool(e['days'] as int))),
                  const Spacer(),
                  Text("闲置 ${e['days']} 天",
                      style: KittStyle.label(size: 12, color: KittColors.textDim, spacing: 1)),
                ]))
        ]);
  }

  Color _cool(int days) {
    if (days >= 5) return KittColors.red;
    if (days >= 2) return KittColors.amber;
    return KittColors.cyan;
  }
}

/// Compat wrapper for older callers (node cards): dark cockpit card.
class BlurCard extends StatelessWidget {
  const BlurCard(this.content,
      {super.key, this.left = 0, this.right = 0, this.top = 0, this.bottom = 25});
  final Widget content;
  final double left;
  final double right;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(left: left, right: right, top: top, bottom: bottom),
      child: KittPanel(padding: EdgeInsets.zero, child: content));
}
