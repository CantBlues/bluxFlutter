import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class Heat extends StatefulWidget {
  Heat({Key? key}) : super(key: key);

  @override
  State<Heat> createState() => _HeatState();
}

class _HeatState extends State<Heat> {
  @override
  Widget build(BuildContext context) {
    var events = {Offset(100, 200): 50};
    for (var i = 0; i < 10000; i++) {
      var _offset =
          Offset(Random().nextDouble() * 300, Random().nextDouble() * 1000);
      events[_offset] = Random().nextInt(20);
    }
    return Scaffold(
      body: Container(
        child: FutureBuilder<Uint8List>(
            future: GenerateHeatMap(360, 1000, events, 30),
            builder: (context, snapshot) {
              if (snapshot.data == null ||
                  snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              return Image(
                image: MemoryImage(snapshot.data!),
              );
            }),
      ),
    );
  }
}

Future<Uint8List> GenerateHeatMap(
    double _width, double _height, Map<Offset, int> events,
    [double radius = 80]) async {
  // init empty canvas
  final pictureRecorder = ui.PictureRecorder();
  var canvas = Canvas(pictureRecorder);

  //  draw heat points
  events.forEach(
      (key, value) => _drawCircle(canvas, key.dx, key.dy, radius, value));

  var canvasPicture = pictureRecorder.endRecording();

  //  process raw image data
  var _img = await canvasPicture.toImage(_width.toInt(), _height.toInt());
  var data = await _img.toByteData();
  var dataList = data!.buffer.asUint8List();
  dataList = _mapRainbow(dataList);

  // decode raw rgba to png format
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(dataList, _width.toInt(), _height.toInt(),
      ui.PixelFormat.rgba8888, completer.complete);
  var img = await completer.future;
  var png = await img.toByteData(format: ui.ImageByteFormat.png);

  return png!.buffer.asUint8List();
}

_drawCircle(Canvas canvas, double x, double y, double radial,
    [int weight = 50]) {
  var painter = Paint();
  painter.shader = ui.Gradient.radial(Offset(x, y), radial,
      [Colors.white.withAlpha(weight), Colors.transparent]);

  painter.blendMode = BlendMode.plus;

  canvas.drawCircle(Offset(x, y), radial, painter);
}

Uint8List _mapRainbow(Uint8List img, [int alpha = 255]) {
  var rainbow = _generateRainbow();

  int pixels = img.length ~/ 4;
  for (int i = 0; i < pixels; i++) {
    var offset = i * 4;
    if (img[offset] != 0) {
      List<int> a = rainbow[255 - img[offset + 3]];

      img[offset] = a[0];
      img[offset + 1] = a[1];
      img[offset + 2] = a[2];
      img[offset + 3] = alpha;
    }
  }
  return img;
}

List<List<int>> _generateRainbow() {
  int r, g, b = 0;
  int total = 256;
  List<List<int>> colors = [];
  for (int i = 0; i < total; i++) {
    if (i < total / 3) {
      r = 255;
      g = (255 * 3 * i / total).ceil();
      b = 0;
    } else if (i < total / 2) {
      r = (750 - i * (250 * 6 / total)).ceil();
      g = 255;
      b = 0;
    } else if (i < total * 2 / 3) {
      r = 0;
      g = 255;
      b = (i * (250 * 6 / total) - 750).ceil();
    } else if (i < total * 5 / 6) {
      r = 0;
      g = (1250 - i * (250 * 6 / total)).ceil();
      b = 255;
    } else {
      r = (150 * i * (6 / total) - 750).ceil();
      g = 0;
      b = 255;
    }
    colors.add([r, g, b]);
  }
  return colors;
}
