// annual task
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_annual_task/flutter_annual_task.dart';
// import 'package:fl_chart/fl_chart.dart';
import 'package:dio/dio.dart';
import 'utils/network.dart';
import 'dart:convert';

// class ContributionPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         body: ListView(
//       children: [DaysView()],
//     ));
//   }
// }

// class DaysView extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<LineChartData>(
//         future: usageData,
//         builder: (context, snap) {
//           return ConstrainedBox(
//             constraints: BoxConstraints(maxHeight: 300),
//             child: LineChart(
//               snap.data ?? LineChartData(),
//               swapAnimationDuration: Duration(milliseconds: 150), // Optional
//               swapAnimationCurve: Curves.linear,
//             ),
//           );
//         });
//   }

//   Future<LineChartData> get usageData async => LineChartData(
//         lineTouchData: lineTouchData1,
//         gridData: gridData,
//         titlesData: titlesData1,
//         lineBarsData: [
//           await pastYearData,
//         ],
//         minX: 0,
//         maxX: 449,
//         maxY: 1440,
//       );

//   LineTouchData get lineTouchData1 => LineTouchData(
//         handleBuiltInTouches: true,
//         touchTooltipData: LineTouchTooltipData(
//           tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
//         ),
//       );

//   Future<LineChartBarData> get pastYearData async {
//     List<FlSpot> spots = [];
//     Response res = await dio.post("/usage/getData");
//     if (res.statusCode == 200) {
//       var data = jsonDecode(res.data.toString());
//       int p = 0;
//       for (var i = 0; i < data['Usage'].length; i++) {
//         if (data['Usage'][i]['Appid'] == 0) {
//           spots.add(FlSpot(p.toDouble(), data['Usage'][i]['Usage'] / 60));
//           print('$p duration : ${data['Usage'][i]['Usage']/60}');
//           p++;
//         }
//       }

//       print("load data from server success!");
//     }
//     return LineChartBarData(
//       isCurved: true,
//       colors: [const Color(0xff4af699)],
//       barWidth: 2,
//       isStrokeCapRound: true,
//       dotData: FlDotData(show: false),
//       belowBarData: BarAreaData(show: false),
//       spots: spots,
//     );
//   }

//   FlTitlesData get titlesData1 => FlTitlesData(
//         bottomTitles: bottomTitles,
//         rightTitles: SideTitles(showTitles: false),
//         topTitles: SideTitles(showTitles: false),
//         leftTitles: leftTitles(
//           getTitles: (value) {
//             switch (value.toInt()) {
//               case 1:
//                 return '1m';
//               case 2:
//                 return '2m';
//               case 3:
//                 return '3m';
//               case 4:
//                 return '5m';
//             }
//             return '';
//           },
//         ),
//       );

//   SideTitles leftTitles({required GetTitleFunction getTitles}) => SideTitles(
//         getTitles: getTitles,
//         showTitles: true,
//         margin: 8,
//         interval: 1,
//         reservedSize: 40,
//         getTextStyles: (context, value) => const TextStyle(
//           color: Color(0xff75729e),
//           fontWeight: FontWeight.bold,
//           fontSize: 14,
//         ),
//       );

//   SideTitles get bottomTitles => SideTitles(
//         showTitles: true,
//         reservedSize: 22,
//         margin: 10,
//         interval: 1,
//         getTextStyles: (context, value) => const TextStyle(
//           color: Color(0xff72719b),
//           fontWeight: FontWeight.bold,
//           fontSize: 16,
//         ),
//         getTitles: (value) {
//           switch (value.toInt()) {
//             case 2:
//               return 'SEPT';
//             case 7:
//               return 'OCT';
//             case 12:
//               return 'DEC';
//           }
//           return '';
//         },
//       );

//   FlGridData get gridData => FlGridData(show: false);
//   FlBorderData get borderData => FlBorderData(
//         show: true,
//         border: const Border(
//           bottom: BorderSide(color: Color(0xff4e4965), width: 4),
//           left: BorderSide(color: Colors.transparent),
//           right: BorderSide(color: Colors.transparent),
//           top: BorderSide(color: Colors.transparent),
//         ),
//       );
// }
