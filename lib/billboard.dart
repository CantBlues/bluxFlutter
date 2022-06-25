// annual task
import 'dart:ui';

import 'package:blux/videoList.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:dio/dio.dart';
import 'utils/network.dart';
import 'dart:convert';

class Billboard extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _BillboardState();
}

class _BillboardState extends State<Billboard> {
  String _task = "sum";

  @override
  Widget build(BuildContext context) {
    return Material(
        color: Colors.transparent,
        child: Container(
            margin: EdgeInsets.all(20),
            child: Column(
              children: [
                BlurCard(ContributionView()),
                Expanded(child: BlurCard(BarChartView())),
                Row(children: [Expanded(child: BlurCard(Container(
                    width: double.infinity,
                    height:60,
                    child:TextButton(
                      child: Text("sum"),
                      onPressed: () => print("aaa"),
                    )))),Container(width:25),Expanded(child: BlurCard(Container(
                    width: double.infinity,
                    height:60,
                    child:TextButton(
                      child: Text("close"),
                      onPressed: () => print("aaa"),
                    ))))]),
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
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 220,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Center(
                child: HeatMap(
                    defaultColor: Color.fromARGB(99, 236, 236, 236),
                    colorsets: {
                  1: Colors.blue,
                }))
          ],
        ));
  }
}

class BarChartView extends StatelessWidget {
  const BarChartView();

  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity);
  }
}
