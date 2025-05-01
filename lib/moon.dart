import 'dart:ui';
import 'package:blux/utils/network.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class MoonPage extends StatelessWidget {
  const MoonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
        child: Container(
            margin: const EdgeInsets.only(top: 50),
            child: Column(
              children: [
                const Text("Moon Phase 2023",
                    style:
                        TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                MoonPhase()
              ],
            )));
  }
}

class MoonPhase extends StatefulWidget {
  const MoonPhase({super.key});

  @override
  State<MoonPhase> createState() => _MoonPhaseState();
}

class _MoonPhaseState extends State<MoonPhase> {
  bool outter = true;
  double angleCalendar = 0;
  double angleEarth = 0;
  double initAngle = 0;
  double preAngle = 0;
  @override
  Widget build(BuildContext context) {
    double width = MediaQueryData.fromView(window).size.width;
    double halfSize = width / 2;
    return Container(
        child: GestureDetector(
      onPanDown: (details) {
        var x = details.localPosition.dx;
        var y = details.localPosition.dy;
        initAngle =
            details.localPosition.translate(-halfSize, -halfSize).direction *
                57;
        // angle = radian * 180 / pi
        // detect pan down on outter or inner

        if ((x < width / 4) ||
            (y < width / 4) ||
            (x > 3 * width / 4) ||
            (y > 3 * width / 4)) {
          outter = true;
          preAngle = angleCalendar;
        } else {
          outter = false;
          preAngle = angleEarth;
        }
      },
      onPanUpdate: ((details) {
        var angle =
            (details.localPosition.translate(-halfSize, -halfSize).direction *
                        57 -
                    initAngle) /
                30;
        angle = angle + preAngle;
        if (outter) {
          setState(() {
            angleCalendar = angle;
          });
        } else {
          setState(() {
            angleEarth = angle;
          });
        }
      }),
      child: Stack(children: [
        Transform.rotate(
            angle: angleCalendar,
            child:
                CachedNetworkImage(imageUrl: "$Domain/storage/calendar.png")),
        Transform.rotate(
          angle: angleEarth,
          child:
              CachedNetworkImage(imageUrl: "$Domain/storage/viewonearth.png"),
        ),
        CachedNetworkImage(imageUrl: "$Domain/storage/main.png")
      ]),
    ));
  }
}
