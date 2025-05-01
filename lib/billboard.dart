import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'utils/network.dart';
import 'dart:convert';

class Billboard extends StatefulWidget {
  const Billboard({super.key});

  @override
  State<StatefulWidget> createState() => _BillboardState();
}

class _BillboardState extends State<Billboard> {
  String _type = "Sum";
  bool _loading = true;
  bool _contributionLoading = true;
  List _typeMenu = [];
  List _contributionData = [];
  Map<String, List> _barData = {};

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

  getBarData() {
    dioLara.get("/api/tasks/compare2month").then((response) {
      var data = jsonDecode(response.data);
      Map<String, List> tmp = {
        "this_month": data["data"]["this_month"],
        "last_month": data["data"]["last_month"]
      };
      setState(() {
        _barData = tmp;
      });
    });
  }

  @override
  void initState() {
    getContributionData(_type);
    getBarData();
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
            ? const Center(child: CircularProgressIndicator())
            : Container(
                margin: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    BlurCard(_contributionLoading
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : ContributionView(_type, _contributionData)),
                    Expanded(child: BlurCard(BarChartView(_barData))),
                    BlurCard(PercentageView(_barData, _typeMenu)),
                    Row(children: [
                      Expanded(
                          child: BlurCard(SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: PopupMenuButton(
                          offset: const Offset(80, 0),
                          child: Center(
                              child: Text(_type,
                                  style: const TextStyle(color: Colors.white))),
                          itemBuilder: (context) {
                            List<PopupMenuEntry> menus = [];
                            menus.add(const PopupMenuItem(
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
                            String name0 = value.toString();
                            getContributionData(name0);
                          },
                        ),
                      ))),
                      Container(width: 25),
                      Expanded(
                          child: BlurCard(SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: TextButton(
                                child: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                              ))))
                    ]),
                  ],
                )));
  }
}

class BlurCard extends StatelessWidget {
  const BlurCard(this.content,
      {super.key, this.left = 0, this.right = 0, this.top = 0, this.bottom = 25});
  final Widget content;
  final double left;
  final double right;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding:
            EdgeInsets.only(left: left, right: right, top: top, bottom: bottom),
        child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(15)),
            child: Stack(children: [
              BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    color: const Color.fromARGB(20, 0, 0, 0),
                    child: content,
                  )),
            ])));
  }
}

class ContributionView extends StatelessWidget {
  const ContributionView(this.name, this.data, {super.key});
  final String name;
  final List data;

  @override
  Widget build(BuildContext context) {
    Map<DateTime, int> datasets = {};
    if (name == "Sum") {
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
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: HeatMap(
                    scrollable: true,
                    datasets: datasets,
                    showColorTip: false,
                    defaultColor: const Color.fromARGB(99, 236, 236, 236),
                    colorsets: const {
                      1: Colors.pink,
                    }))));
  }
}

class BarChartView extends StatelessWidget {
  const BarChartView(this.data, {super.key});
  final Map<String, List> data;

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
    List<BarChartGroupData> items = [];
    Map<String, List<double>> tasks = {};
    if (data["this_month"] != null) {
      for (var element in data["this_month"]!) {
        tasks[element["name"]] = [element["times"] / 1];
      }
      for (var element in data["last_month"]!) {
        tasks[element["name"]]?.add(element["times"] / 1);
      }
    }

    int i = 0;
    List<String> name = [];
    tasks.forEach((key, value) {
      BarChartGroupData tmp =
          makeGroupData(i, value[0], value.length == 2 ? value[1] : 0);
      if (i < 7) items.add(tmp);
      name.add(key);
      i++;
    });

    return Container(
        child: data["this_month"] == null
            ? const CircularProgressIndicator()
            : BarChart(BarChartData(
                maxY: 31,
                minY: 0,
                barTouchData: BarTouchData(
                    touchTooltipData:
                        BarTouchTooltipData(fitInsideVertically: true)),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (num, TitleMeta a) {
                            return Transform.rotate(
                                angle: -0.8,
                                child: Center(
                                    child: Text(name[num.round()])));
                          })),
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                ),
                borderData: FlBorderData(
                  show: false,
                ),
                barGroups: items,
                gridData: const FlGridData(show: false),
              )));
  }
}

class PercentageView extends StatelessWidget {
  const PercentageView(this.data, this.types, {super.key});

  final Map<String, List> data;
  final List types;

  popPE(context, pie) {
    showDialog(
        context: context,
        builder: (context) {
          return GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: ExerciseList(pie));
        });
  }

  @override
  Widget build(BuildContext context) {
    List pieData = [];
    List<String> body = [];
    List<String> soul = [];
    List<String> steps = [];

    for (var element in types) {
      switch (element["classify"]) {
        case "body":
          body.add(element["name"]);
          break;
        case "soul":
          soul.add(element["name"]);
          break;
        case "steps":
          steps.add(element["name"]);
          break;
        default:
      }
    }
    int soulNum = 0;
    int stepsNum = 0;
    if (data["this_month"] != null) {
      for (var element in data["this_month"]!) {
        if (body.contains(element["name"])) {
          pieData.add(element);
        }

        int weight = element["weight"];
        if (soul.contains(element["name"])) {
          soulNum += int.parse(element["times"].toString()) * weight;
        }
        if (steps.contains(element["name"])) {
          stepsNum += int.parse(element["times"].toString()) * weight;
        }
      }
    }

    int drop = stepsNum - soulNum;
    double angle = drop / 50;
    return Container(
        padding: const EdgeInsets.all(20),
        height: 200,
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
                child: Center(
                    child: Stack(
              children: [
                Align(
                    alignment: const Alignment(0, -0.6),
                    child: Text("Soul: $soulNum , Steps: $stepsNum ")),
                CustomPaint(
                  size: const Size(300, 300),
                  painter: Seesaw(angle),
                )
              ],
            ))),
            Expanded(
                child: GestureDetector(
              child: Center(child: PhysicalPie(pieData, false)),
              onTap: () => popPE(context, pieData),
            ))
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
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
    for (var element in data) {
      pieSum += element["times"];
      PieChartSectionData part = PieChartSectionData(
          radius: big ? 100 : 45,
          title: "${element["name"]}:${element["times"]}",
          value: element["times"] / 1,
          color: Color.fromARGB(255, Random().nextInt(128) + 128,
              Random().nextInt(128) + 128, Random().nextInt(128) + 128));
      pieData.add(part);
    }

    return Stack(
      children: [
        PieChart(
          PieChartData(
            sections: pieData,
            sectionsSpace: 8,
          ),
          swapAnimationDuration: const Duration(seconds: 2),
        ),
        Center(
            child: Text(
          pieSum.toString(),
          style: const TextStyle(
              fontSize: 30,
              shadows: [Shadow(color: Colors.white, blurRadius: 20)]),
        ))
      ],
    );
  }
}

class ExerciseList extends StatefulWidget {
  const ExerciseList(this.pie, {super.key});
  final pie;
  @override
  _ExerciseListState createState() => _ExerciseListState();
}

class _ExerciseListState extends State<ExerciseList> {
  List<Widget> list = [];
  @override
  void initState() {
    list.add(Container(
        margin: const EdgeInsets.only(top: 30),
        width: 260,
        height: 260,
        child: PhysicalPie(widget.pie, true)));
    laravel.get("recently_exercise").then((value) => sortTask(value.data));
    super.initState();
  }

  sortTask(data) {
    DateTime now = DateTime.now();
    List<Map?> tasks = [];
    for (var element in data["data"]) {
      DateTime date = DateTime.parse(element['date']);
      int days = now.difference(date).inDays;
      Map? task;

      if (days >= 1) {
        if (days == 1) {
          task = {"sort": 2, "content": "${element["name"]} >24h"};
        }
        if (days == 2) {
          task = {"sort": 3, "content": "${element["name"]} >48h"};
        }
        if (days > 2 && days < 5) {
          task = {"sort": 4, "content": "${element["name"]} >72h"};
        }
        if (days >= 5) {
          task = {"sort": 1, "content": "${element["name"]} >120h"};
        }
      }

      if (task != null) tasks.add(task);
    }

    tasks.sort(((a, b) => a?["sort"] - b?["sort"]));

    for (var i = 0; i < tasks.length; i++) {
      double scale = 1;
      Color color;
      switch (tasks[i]!["sort"]) {
        case 4:
          color = Colors.red;
          scale = 4;
          break;
        case 3:
          color = Colors.orange;
          scale = 3.3;
          break;
        case 2:
          color = Colors.blue;
          scale = 2.5;
          break;
        case 1:
          color = Colors.deepPurple;
          scale = 2;
          break;
        default:
          color = Colors.black;
      }
      Widget widget = Container(
          padding: const EdgeInsets.only(top: 20),
          child: Text(tasks[i]!['content'],
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: scale * 12,
                  shadows: const [Shadow(color: Colors.white, blurRadius: 5)])));
      list.add(widget);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(20),
          child: Column(
            verticalDirection: VerticalDirection.up,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: list,
          ),
        ));
  }
}
