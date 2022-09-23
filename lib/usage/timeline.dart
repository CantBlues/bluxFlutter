import 'dart:math';
import 'dart:typed_data';
import 'usage_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_heat_map/flutter_heat_map.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'package:usage_stats/usage_stats.dart';

const BgColor = Color.fromARGB(255, 223, 223, 223);

class UsageTimeLine extends StatelessWidget {
  const UsageTimeLine({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Timeline")),
      backgroundColor: BgColor,
      body: Container(
          margin: EdgeInsets.all(15),
          child: ChangeNotifierProvider(
            create: ((context) => HourProvider()),
            builder: (context, _) {
              return LayoutBuilder(builder: (context, constraints) {
                context.read<HourProvider>().maxWidth = constraints.maxWidth;
                final date = context.watch<HourProvider>().date;
                return NotificationListener(
                  onNotification: (notification) => true,
                  child: Column(
                    children: [
                      HeaderBox(),
                      TimeLineBox(),
                      ElevatedButton(
                          onPressed: () async {
                            final pick = await showDatePicker(
                                context: context,
                                initialDate: date,
                                firstDate: date.subtract(Duration(days: 100)),
                                lastDate: DateTime.now());
                            if (pick != null)
                              context.read<HourProvider>().date = pick;
                          },
                          child: Container(
                              alignment: Alignment(0, 0),
                              width: double.infinity,
                              height: 50,
                              child: Text(
                                "Select Date: ${date.toString().substring(0, 10)}",
                                style: TextStyle(fontSize: 20),
                              )))
                    ],
                  ),
                );
              });
            },
          )),
    );
  }
}

class HourProvider extends ChangeNotifier {
  double sunrise = 100;
  double daytime = 200;
  double offset = 0;
  double _maxWidth = 0;
  DateTime _date = DateTime.now();
  DateTime get date => _date;

  set date(d) {
    _date = d;
    notifyListeners();
  }

  List<EventUsageInfo> usages = [];

  getUsages(List<EventUsageInfo> data) {
    usages = data;
    notifyListeners();
  }

  double get maxWidth => _maxWidth;
  set maxWidth(w) {
    _maxWidth = w;
    final x = w - 50;
    sunrise = x / 4;
    daytime = x / 2;
  }

  change(double x) {
    offset = x;
    notifyListeners();
  }
}

class HeaderBox extends StatelessWidget {
  const HeaderBox({Key? key}) : super(key: key);

  Widget _boxDayNight(double sunrise, double daytime) {
    return Container(
        height: 40,
        padding: EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 5),
        child: Row(
          children: [
            Container(
              child: Image.asset("assets/moon.png"),
              width: sunrise,
              padding: EdgeInsets.all(5),
              margin: EdgeInsets.only(right: 15),
              decoration: BoxDecoration(
                  color: Color.fromRGBO(101, 97, 97, 1),
                  borderRadius: BorderRadius.all(Radius.circular(10))),
            ),
            Container(
              child: Image.asset("assets/sun.png"),
              width: daytime,
              padding: EdgeInsets.all(5),
              margin: EdgeInsets.only(right: 15),
              decoration: BoxDecoration(
                  color: Color.fromRGBO(255, 201, 102, 1),
                  borderRadius: BorderRadius.all(Radius.circular(10))),
            ),
            Expanded(
              child: Container(
                child: Image.asset("assets/moon.png"),
                padding: EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: Color.fromRGBO(101, 97, 97, 1),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
            ),
          ],
        ));
  }

  Widget _hoursTips(double sunrise, double daytime) {
    return Container(
      margin: EdgeInsets.all(10),
      child: Row(children: [
        Padding(
            padding: EdgeInsets.only(right: sunrise - 10), child: Text("00")),
        Padding(padding: EdgeInsets.only(right: daytime), child: Text("06")),
        Text("17")
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    var _sunrise = context.watch<HourProvider>().sunrise;
    var _daytime = context.watch<HourProvider>().daytime;

    return Container(
        height: 120,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(10))),
        child: Stack(
          children: [
            Column(
              children: [
                _boxDayNight(_sunrise, _daytime),
                HeatBox(),
                _hoursTips(_sunrise, _daytime)
              ],
            ),
            SlideHandle()
          ],
        ));
  }
}

class HeatBox extends StatefulWidget {
  HeatBox({Key? key}) : super(key: key);

  @override
  State<HeatBox> createState() => _HeatBoxState();
}

class _HeatBoxState extends State<HeatBox> {
  Future<Uint8List?>? _bytes;
  DateTime _date = DateTime.now().add(Duration(seconds: 1));
  bool _loading = false;

  Future<Uint8List?> _generateImg(
      double _width, List<HeatMapEvent> events) async {
    if (events.length == 0) return null;
    Uint8List imgBytes;
    final pictureRecorder = ui.PictureRecorder();
    Canvas(pictureRecorder);
    var canvasPicture = pictureRecorder.endRecording();

    var _img = await canvasPicture.toImage(_width.toInt() * 50, 130);
    var a = await _img.toByteData(format: ui.ImageByteFormat.png);
    imgBytes = a!.buffer.asUint8List();
    ui.Image? image =
        await HeatMap.imageProviderToUiImage(MemoryImage(imgBytes));
    var data = HeatMapPage(image: image, events: events);

    final s = DateTime.now();
    var bytes = await HeatMap.process(
        data, HeatMapConfig(uiElementSize: 13, heatMapTransparency: 0.7));

    final e = DateTime.now();
    final diff = e.difference(s);
    return bytes;
  }

  _generateHeat(List<EventUsageInfo> events, DateTime date) {
    _date = date;
    var _width = context.read<HourProvider>().maxWidth;
    _width = _width - 20;
    double xPerMinute = _width / (60 * 24);
    List<HeatMapEvent> eventList = [];
    bool recording = false;
    const int minute = 60;
    int vernier =
        DateTime(date.year, date.month, date.day).millisecondsSinceEpoch ~/
            1000;
    double vernierX = 0;

    for (var event in events) {
      int eventStamp = int.parse(event.timeStamp!) ~/ 1000;
      while (recording && vernier < eventStamp) {
        final HeatMapEvent heatpoint =
            HeatMapEvent(location: Offset(vernierX * 50, 65));
        vernierX = vernierX + xPerMinute;
        vernier += minute;
        eventList.add(heatpoint);
      }
      int type = int.parse(event.eventType!);
      if (type == 15) {
        while (vernier < eventStamp) {
          vernier += minute;
          vernierX += xPerMinute;
        }

        recording = true;
      }
      if (type == 16) {
        recording = false;
      }
    }
    _bytes = _generateImg(_width, eventList);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final date = context.watch<HourProvider>().date;
    if (date != _date && !_loading) {
      _loading = true;
      final start = date;
      final end = start.add(Duration(days: 1));
      UsageStats.queryEvents(DateTime(start.year, start.month, start.day),
              DateTime(end.year, end.month, end.day))
          .then((value) {
        context.read<HourProvider>().getUsages(value);
        _generateHeat(value, date);
        _loading = false;
      });
    }
    return Container(
        height: 40,
        padding: EdgeInsets.only(left: 10, right: 10),
        color: BgColor,
        child: FutureBuilder<Uint8List?>(
          future: _bytes,
          builder: (context, snap) {
            var data = snap.data;
            return data != null
                ? Image(
                    fit: BoxFit.fill,
                    image: MemoryImage(data),
                  )
                : Container();
          },
        ));
  }
}

class SlideHandle extends StatefulWidget {
  SlideHandle({Key? key}) : super(key: key);

  @override
  State<SlideHandle> createState() => _SlideHandleState();
}

class _SlideHandleState extends State<SlideHandle> {
  double _maxWidth = 0;
  late double _offsetX;
  _dragHandle(DragUpdateDetails e) {
    double _x = e.localPosition.dx;
    if (_x >= 0 && _x <= _maxWidth) {
      double offset = (_x - _maxWidth / 2) / (_maxWidth / 2);
      context.read<HourProvider>().change(offset + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    _maxWidth = context.read<HourProvider>().maxWidth;
    _offsetX = context.watch<HourProvider>().offset;

    return GestureDetector(
        onHorizontalDragUpdate: _dragHandle,
        child: Padding(
          padding: EdgeInsets.only(left: 10, right: 10),
          child: Align(
            alignment: Alignment(_offsetX - 1, 0),
            child: Container(
              height: 120,
              width: 20,
              decoration: BoxDecoration(
                  color: Color.fromRGBO(255, 0, 0, 0.5),
                  borderRadius: BorderRadius.all(Radius.circular(10))),
            ),
          ),
        ));
  }
}

class TimeLineBox extends StatefulWidget {
  TimeLineBox({Key? key}) : super(key: key);

  @override
  State<TimeLineBox> createState() => _TimeLineBoxState();
}

class _TimeLineBoxState extends State<TimeLineBox> {
  List<Widget> _list = [];
  ScrollController _controller = ScrollController();
  double _offset = 0;
  bool _passive = false;
  double _maxH = 0;
  List<EventUsageInfo> _events = [];
  Map<int, double> _timeScale = {};
  double _maxRangeLeft = 0;

  Widget _timeBlock(app, double height) {
    Color color = Color.fromARGB(255, Random().nextInt(200),
        Random().nextInt(200), Random().nextInt(200));
    String name = app['name'];
    var duration = app['duration'] ~/ 1000;
    final date = DateTime.fromMillisecondsSinceEpoch(app['start'].round())
        .toString()
        .substring(11, 19);
    Widget tmp = Container(
        margin: EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                width: 70,
                height: height,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("$date"),
                    Expanded(child: Container(width: 2, color: color))
                  ],
                )),
            Expanded(
                child: Container(
                    child: Row(
                      children: [
                        Container(width: 5, color: color),
                        Container(
                            margin: EdgeInsets.only(left: 20, top: 10),
                            alignment: Alignment(-1, -1),
                            child: Text(
                                '$name\n$duration seconds or ${duration ~/ 60} minutes'))
                      ],
                    ),
                    decoration: BoxDecoration(
                        color: color.withAlpha(150),
                        borderRadius: BorderRadius.all(Radius.circular(10))),
                    clipBehavior: Clip.hardEdge,
                    height: height - 30))
          ],
        ));
    return tmp;
  }

  @override
  void initState() {
    // listen scroll status to controls offset of slidebox
    _controller.addListener(() {
      if (!_passive) {
        var before = _controller.position.extentBefore;
        // prevent callback from build
        double height = 0;
        int hour = 0;
        _timeScale.forEach((key, value) {
          if (before > value) {
            height = value;
            hour = key;
          }
        });
        var clock = 2 / 24;
        var rangeDown = _timeScale[hour + 1] ?? _maxH;

        var result =
            clock * hour + (before - height) / (rangeDown - height) * 2 / 24;

        if (result >= 0 && result <= 2) {
          context.read<HourProvider>().change(result);
          _offset = result;
        }
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final offset = context.watch<HourProvider>().offset;
    final events = context.watch<HourProvider>().usages;

    // controlled by slide box

    if (offset != _offset && _maxH > 0) {
      _passive = true;
      _offset = offset;
      var time = offset / 2 * 24;
      var hour = time ~/ 1;
      var minute = time - hour;

      var rangeLeft = _timeScale[hour] ?? _maxRangeLeft;
      if (rangeLeft > _maxRangeLeft) _maxRangeLeft = rangeLeft;
      var rangeRight = _timeScale[hour + 1] ?? _maxH;
      var target = rangeLeft + (rangeRight - rangeLeft) * minute;
      _controller.jumpTo(target);
      _passive = false;
    }

    // generate usage event list
    if (_events != events) {
      List<Widget> list = [];
      _events = events;

      Map<int, double> timeScale = {0: 0};
      var data = handleEvents(events);
      const double baseHeight = 100;
      const double heightPerBlock = 10;
      const double margin = 20;
      double sumHeight = 0;
      for (var app in data) {
        double height =
            baseHeight + (app['duration'] ~/ 60000) * heightPerBlock;
        height = height > 300 ? 300 : height;

        var time = DateTime.fromMillisecondsSinceEpoch(app['start'].ceil());
        if (!timeScale.containsKey(time.hour)) timeScale[time.hour] = sumHeight;

        final tmp = _timeBlock(app, height);
        list.add(tmp);
        sumHeight += height + margin;
      }
      setState(() {
        _timeScale = timeScale;
        _maxH = sumHeight;
        _list = list;
      });
    }
    return Expanded(
        child: Container(
      margin: EdgeInsets.only(top: 20, bottom: 20),
      child: ListView(
        children: _list,
        controller: _controller,
      ),
    ));
  }
}
