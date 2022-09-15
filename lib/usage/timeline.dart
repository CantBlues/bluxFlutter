import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_heat_map/flutter_heat_map.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;

class UsageTimeLine extends StatelessWidget {
  const UsageTimeLine({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Timeline")),
      backgroundColor: Colors.grey,
      body: Container(
          margin: EdgeInsets.all(15),
          child: ChangeNotifierProvider(
            create: ((context) => HourProvider()),
            builder: (context, _) {
              return LayoutBuilder(builder: (context, constraints) {
                context.read<HourProvider>().maxWidth = constraints.maxWidth;
                return NotificationListener(
                  onNotification: (notification) => true,
                  child: Column(
                    children: [
                      HeaderBox(),
                      TimeLineBox(),
                      ElevatedButton(
                          onPressed: () {},
                          child: Container(
                              alignment: Alignment(0, 0),
                              width: double.infinity,
                              height: 50,
                              child: Text(
                                "Select Date",
                                style:
                                    TextStyle(fontSize: 20, letterSpacing: 2),
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

  double get maxWidth => _maxWidth;
  set maxWidth(w) {
    _maxWidth = w;
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
        Padding(padding: EdgeInsets.only(right: sunrise), child: Text("00")),
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
        height: 130,
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
  late Future<Uint8List?> _bytes;

  Future<Uint8List?> _generateImg(
      double _width, List<HeatMapEvent> events) async {
    Uint8List imgBytes;
    final pictureRecorder = ui.PictureRecorder();
    Canvas(pictureRecorder);
    var canvasPicture = pictureRecorder.endRecording();

    var _img = await canvasPicture.toImage(_width.toInt(), 40);
    var a = await _img.toByteData(format: ui.ImageByteFormat.png);
    imgBytes = a!.buffer.asUint8List();
    ui.Image? image =
        await HeatMap.imageProviderToUiImage(MemoryImage(imgBytes));
    var data = HeatMapPage(image: image, events: events);
    var bytes = await HeatMap.process(data, HeatMapConfig());

    return bytes;
  }

  @override
  void initState() {
    var _width = context.read<HourProvider>().maxWidth;
    var _events = [
      HeatMapEvent(location: Offset(10, 25)),
      HeatMapEvent(location: Offset(12, 25)),
      HeatMapEvent(location: Offset(13, 25)),
      HeatMapEvent(location: Offset(100, 25))
    ];
    _bytes = _generateImg(_width, _events);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snap) {
        var data = snap.data;
        return Container(
            color: Colors.grey,
            child: data != null
                ? Image(
                    image: MemoryImage(data),
                  )
                : null);
      },
    );
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

  Widget _timeBlock() {
    double rand = Random().nextInt(200).toDouble() + 50;
    Color color = Color.fromARGB(255, Random().nextInt(200),
        Random().nextInt(200), Random().nextInt(200));
    Widget tmp = Container(
        margin: EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                width: 100,
                height: rand,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("05:23"),
                    Expanded(child: Container(width: 2, color: color))
                  ],
                )),
            Expanded(
                child: Container(
                    child: Row(
                      children: [
                        Container(width: 5, color: color),
                        Container(
                            margin: EdgeInsets.all(20),
                            alignment: Alignment(-1, -1),
                            child: Text("adfsdfsdfsd"))
                      ],
                    ),
                    decoration: BoxDecoration(
                        color: color.withAlpha(150),
                        borderRadius: BorderRadius.all(Radius.circular(10))),
                    clipBehavior: Clip.hardEdge,
                    height: rand - 30))
          ],
        ));
    return tmp;
  }

  @override
  void initState() {
    // for (var i = 0; i < 100; i++) {
    //   if (i < 10) {
    //     Widget tmp = _timeBlock();
    //     _list.add(tmp);
    //   } else {
    //     _list.add(Text(i.toString()));
    //   }
    // }
    // listen scroll status to controls offset of slidebox
    _controller.addListener(() {
      if (!_passive) {
        // prevent callback from build
        var result = (_controller.position.extentBefore /
                _controller.position.maxScrollExtent) *
            2;
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
    var offset = context.watch<HourProvider>().offset;

    // controlled by slide box
    if (offset != _offset) {
      if (_maxH == 0) {
        _maxH = _controller.position.maxScrollExtent;
      }

      _passive = true;
      _offset = offset * _maxH / 2;
      _controller.jumpTo(_offset);
      _passive = false;
    }

    return Expanded(
        child: Container(
      margin: EdgeInsets.only(top: 20, bottom: 20),
      child: ListView.builder(
        controller: _controller,
        itemCount: 500,
        itemBuilder: ((context, index) {
          if (index < 10) {
            Widget tmp = _timeBlock();
            return tmp;
          } else {
            return Text(index.toString());
          }
        }),
      ),
    ));
  }
}
