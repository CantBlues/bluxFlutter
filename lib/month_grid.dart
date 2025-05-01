import 'package:blux/utils/network.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:hexagon/hexagon.dart';

class HabbitRecordPage extends StatefulWidget {
  const HabbitRecordPage({super.key, required this.id});
  final int id;

  @override
  State<HabbitRecordPage> createState() => _HabbitRecordPageState();
}

class _HabbitRecordPageState extends State<HabbitRecordPage> {
  dynamic data;

  @override
  void initState() {
    super.initState();
    getHabbitRecord();
  }

  getHabbitRecord() async {
    var result = (await laravel.get("habbit/record", queryParameters: {"id": widget.id})).data;
    List<List<int>> formattedData = List.generate(12, (_) => []);
    for (var record in result['data']) {
      DateTime date = DateTime.parse(record['created_at']);
      int month = date.month;
      int day = date.day;
      formattedData[month - 1].add(day);
    }

    setState(() {
      data = formattedData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return data == null ? const Center(child: CircularProgressIndicator()) : MonthGridPage(data: data);
  }
}

class MonthGridPage extends StatelessWidget {
  const MonthGridPage({super.key, required this.data});
  final dynamic data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = constraints.maxHeight;
            final screenWidth = constraints.maxWidth;

            const padding = 2.0; // Padding between cells
            const columns = 12; // Number of months in a row
            const rows = 31; // Maximum days in a month

            final cellWidth = (screenWidth - (columns + 1) * padding) / columns;
            final cellHeight = (screenHeight - 30 - (rows + 1) * padding) / rows;
            final cellSize = min(cellWidth, cellHeight);

            final horizonPadding = (screenWidth - (cellSize + padding) * 12) / 12;

            return Center(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(12, (monthIndex) {
                  return Padding(
                    padding: EdgeInsets.only(left: horizonPadding),
                    child: MonthView(
                      monthIndex: monthIndex + 1,
                      availableHeight: cellSize,
                      padding: padding,
                      monthData: data[monthIndex],
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}

class MonthView extends StatelessWidget {
  final int monthIndex;
  final double availableHeight;
  final double padding;
  final List monthData;

  const MonthView(
      {super.key,
      required this.monthIndex,
      required this.availableHeight,
      required this.padding,
      required this.monthData});

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(2025, monthIndex + 1, 0).day;
    final daySize = availableHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(2.0),
          child: Text(
            '$monthIndex',
            style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        Wrap(
          direction: Axis.vertical,
          spacing: padding,
          runSpacing: padding,
          children: List.generate(
            daysInMonth,
            (dayIndex) => SizedBox(
              width: daySize,
              height: daySize,
              child: HexagonWidget.pointy(
                width: daySize,
                color: monthData.contains(dayIndex + 1) ? Colors.red : Colors.blueGrey,
                child: Center(
                  child: Text(
                    '${dayIndex + 1}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
