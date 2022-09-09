import 'dart:html';
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
                  return Column(
                    children: [
                      HeaderBox(),
                      Text(context.watch<HourProvider>().offset.toString())
                    ],
                  );
                });
              },
            )));
  }
}

class HourProvider extends ChangeNotifier {
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

  Widget _boxDayNight() {
    return Container();
  }

  Widget _hoursTips() {
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 200,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(10))),
        child: Stack(
          children: [
            Column(
              children: [_boxDayNight(), HeatBox(), _hoursTips()],
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

    var _img = await canvasPicture.toImage(_width.toInt(), 50);
    var a = await _img.toByteData(format: ui.ImageByteFormat.png);
    imgBytes = a!.buffer.asUint8List();
    ui.Image? image =
        await HeatMap.imageProviderToUiImage(MemoryImage(imgBytes));
    var data = HeatMapPage(image: image, events: events);
    var bytes = await HeatMap.process(data,HeatMapConfig());

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
            // color: Color.fromARGB(100, 100, 0, 0),
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
  double _offsetX = -1;
  _dragHandle(DragUpdateDetails e) {
    double _x = e.localPosition.dx;
    if (_x >= 0 && _x <= _maxWidth) {
      double _offset = (_x - _maxWidth / 2) / (_maxWidth / 2);
      setState(() {
        _offsetX = _offset;
      });
      context.read<HourProvider>().change(_offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    _maxWidth = context.read<HourProvider>().maxWidth;
    return GestureDetector(
        onHorizontalDragUpdate: _dragHandle,
        child: OverflowBox(
            alignment: Alignment(_offsetX, 0),
            maxHeight: 210,
            child: Container(
                height: 210,
                decoration: BoxDecoration(
                    color: Color.fromRGBO(255, 0, 0, 0.5),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                width: 20)));
  }
}
