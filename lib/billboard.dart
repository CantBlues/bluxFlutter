// annual task
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
// import 'package:dio/dio.dart';
import 'utils/network.dart';
import 'dart:convert';

class Billboard extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _BillboardState();
}

class _BillboardState extends State<Billboard> {
  String _type = "Sum";
  bool _loading = true;
  bool _contributionLoading = true;
  List _typeMenu = [];
  List _contributionData = [];

  getContributionData(String type) {
    dioLara.get("/api/tasks/contribution?type=$type").then((response) {
      var data = jsonDecode(response.data);
      setState(() {
        _contributionLoading = false;
        _contributionData = data["data"];
        _type = type;
      });
    });
  }

  @override
  void initState() {
    getContributionData(_type);
    dioLara.get("/api/tasktypes").then((response) {
      var data = jsonDecode(response.data);
      setState(() {
        _typeMenu = data["data"];
        _loading = false;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        color: Colors.transparent,
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : Container(
                margin: EdgeInsets.all(20),
                child: Column(
                  children: [
                    BlurCard(_contributionLoading
                        ? Center(
                            child: CircularProgressIndicator(),
                          )
                        : ContributionView(_type, _contributionData)),
                    SizedBox(height: 200, child: BlurCard(BarChartView())),
                    BlurCard(PercentageView()),
                    Row(children: [
                      Expanded(
                          child: BlurCard(Container(
                        width: double.infinity,
                        height: 60,
                        child: PopupMenuButton(
                          child: Center(
                              child: Text(_type,
                                  style: TextStyle(color: Colors.white))),
                          itemBuilder: (context) {
                            List<PopupMenuEntry> menus = [];
                            menus.add(PopupMenuItem(
                                value: "Sum", child: Text("Sum")));
                            for (var element in _typeMenu) {
                              String name = element["name"];
                              PopupMenuItem item =
                                  PopupMenuItem(value: name, child: Text(name));
                              menus.add(item);
                            }
                            return menus;
                          },
                          onSelected: (value) {
                            String _name = value.toString();
                            getContributionData(_name);
                          },
                        ),
                      ))),
                      Container(width: 25),
                      Expanded(
                          child: BlurCard(Container(
                              width: double.infinity,
                              height: 60,
                              child: TextButton(
                                child: Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                              ))))
                    ]),
                  ],
                )));
  }
}

class BlurCard extends StatelessWidget {
  const BlurCard(this.content);
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.only(bottom: 25),
        child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            child: Stack(children: [
              BackdropFilter(
                  child: Container(
                    color: Color.fromARGB(20, 0, 0, 0),
                    child: content,
                  ),
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15)),
            ])));
  }
}

class ContributionView extends StatelessWidget {
  const ContributionView(this.name, this.data);
  final String name;
  final List data;

  @override
  Widget build(BuildContext context) {
    Map<DateTime, int> datasets = {};
    if (name == "Sum" ) {
      for (var element in data) {
        datasets[DateTime.parse(element["date"])] = int.parse(element['sum']);
      }
    } else {
      for (var element in data) {
        datasets[DateTime.parse(element["date"])] = 1;
      }
    }

    return SizedBox(
        height: 220,
        child: Center(
            child: Padding(
                padding: EdgeInsets.only(left: 10, right: 10),
                child: HeatMap(
                    scrollable: true,
                    datasets: datasets,
                    showColorTip: false,
                    defaultColor: Color.fromARGB(99, 236, 236, 236),
                    colorsets: {
                      1: Colors.pink,
                    }))));
  }
}

class BarChartView extends StatelessWidget {
  const BarChartView();

  BarChartGroupData makeGroupData(int x, double y1, double y2) {
    return BarChartGroupData(barsSpace: 4, x: x, barRods: [
      BarChartRodData(
        toY: y1,
        color: Colors.red,
        width: 10,
      ),
      BarChartRodData(
        toY: y2,
        color: Colors.blue,
        width: 10,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    List<BarChartGroupData> showingBarGroups;
    final barGroup1 = makeGroupData(0, 5, 12);
    final barGroup2 = makeGroupData(1, 16, 12);
    final barGroup3 = makeGroupData(2, 18, 5);
    final barGroup4 = makeGroupData(3, 20, 16);
    final barGroup5 = makeGroupData(4, 17, 6);
    final barGroup6 = makeGroupData(5, 19, 1.5);
    final barGroup7 = makeGroupData(6, 10, 1.5);
    final barGroup8 = makeGroupData(6, 10, 1.5);
    final barGroup9 = makeGroupData(6, 10, 1.5);

    final items = [
      barGroup1,
      barGroup2,
      barGroup3,
      barGroup4,
      barGroup5,
      barGroup6,
      barGroup7,
      barGroup8,
      barGroup9
    ];

    showingBarGroups = items;
    return Container(
        // width: double.infinity,
        child: BarChart(BarChartData(
      maxY: 30,
      minY: 10,
      titlesData: FlTitlesData(
        show: true,
        leftTitles: AxisTitles(),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: false,
      ),
      barGroups: showingBarGroups,
      gridData: FlGridData(show: false),
    )));
  }
}

class PercentageView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    List<PieChartSectionData> pieData = [
      PieChartSectionData(value: 10, color: Colors.pink),
      PieChartSectionData(value: 8, color: Colors.blue)
    ];
    return Container(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
                child: Center(
                    child: CustomPaint(
              size: Size(300, 300),
              painter: Seesaw(),
            ))),
            Expanded(
                child: Center(child: PieChart(PieChartData(sections: pieData))))
          ],
        ),
        height: 200,
        width: double.infinity);
  }
}

class Seesaw extends CustomPainter {
  Float64List transit(double dx, double dy) {
    return Float64List.fromList(
        [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1]);
  }

  Float64List rotate(num x) {
    return Float64List.fromList(
        [cos(x), sin(x), 0, 0, -sin(x), cos(x), 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
  }

  Float64List scale(double x, double y) {
    return Float64List.fromList(
        [x, 0, 0, 0, 0, y, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
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
      ..color = Colors.red
      ..strokeWidth = 4;
    Paint painterPlank = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.fill
      ..color = Colors.blue
      ..strokeWidth = 4;
    painterPlank.color = Colors.blue;
    Path tri = Path()..moveTo(peak.dx, peak.dy);
    tri.lineTo(left.dx, left.dy);
    tri.lineTo(right.dx, right.dy);
    double _width = size.width / 3;

    Path plank = Path()..moveTo(peak.dx - _width, peak.dy - 10);
    plank.lineTo(peak.dx - _width, peak.dy);
    plank.lineTo(peak.dx + _width, peak.dy);
    plank.lineTo(peak.dx + _width, peak.dy - 10);

    double degree = 0.2;
    plank = plank.transform(rotate(degree));
    double afterX = peak.dx * cos(degree) - peak.dy * sin(degree);
    double afterY = (peak.dx) * sin(degree) + peak.dy * cos(degree);
    plank = plank.transform(transit(peak.dx - afterX, peak.dy - afterY));

    canvas.drawPath(tri, painter);
    canvas.drawPath(plank, painterPlank);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
