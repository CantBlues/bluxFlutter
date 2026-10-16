import 'dart:math';
import 'package:blux/kitt/theme.dart';
import 'package:blux/kitt/widgets.dart';
import 'package:blux/local/local_db.dart';
import 'package:flutter/material.dart';
import 'package:hexagon/hexagon.dart';

/// One habit's whole year drawn as 12 columns of hex cells — lit cells are
/// recorded days. Reads entirely from the local database.
class HabbitRecordPage extends StatefulWidget {
  const HabbitRecordPage({super.key, required this.id, this.name});
  final int id;
  final String? name;

  @override
  State<HabbitRecordPage> createState() => _HabbitRecordPageState();
}

class _HabbitRecordPageState extends State<HabbitRecordPage> {
  List<List<int>>? data;

  @override
  void initState() {
    super.initState();
    getHabbitRecord();
  }

  getHabbitRecord() async {
    final matrix = await HabitRepo.yearMatrix(widget.id);
    if (!mounted) return;
    setState(() {
      data = matrix;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: KittColors.bg,
        appBar: AppBar(title: Text("习惯年度 // ${widget.name ?? ''}")),
        body: data == null
            ? const Center(child: CircularProgressIndicator())
            : MonthGridPage(data: data!));
  }
}

class MonthGridPage extends StatelessWidget {
  const MonthGridPage({super.key, required this.data});
  final List<List<int>> data;

  @override
  Widget build(BuildContext context) {
    return GridBackdrop(
        child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;
          final screenWidth = constraints.maxWidth;

          const padding = 2.0;
          const columns = 12;
          const rows = 31;

          final cellWidth = (screenWidth - (columns + 1) * padding) / columns;
          final cellHeight = (screenHeight - 40 - (rows + 1) * padding) / rows;
          final cellSize = min(cellWidth, cellHeight);
          final horizonPadding =
              (screenWidth - (cellSize + padding) * columns) / columns;

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
    ));
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
    final daysInMonth = DateTime(DateTime.now().year, monthIndex + 1, 0).day;
    final daySize = availableHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(2.0),
          child: Text(
            monthIndex.toString().padLeft(2, '0'),
            style: const TextStyle(
                fontSize: 13,
                color: KittColors.amber,
                fontWeight: FontWeight.bold,
                fontFamily: KittStyle.mono),
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
                color: monthData.contains(dayIndex + 1)
                    ? KittColors.red
                    : KittColors.panelSoft,
                child: Center(
                  child: Text(
                    '${dayIndex + 1}',
                    style: TextStyle(
                        fontSize: daySize * .35,
                        fontWeight: FontWeight.bold,
                        fontFamily: KittStyle.mono,
                        color: monthData.contains(dayIndex + 1)
                            ? Colors.white
                            : KittColors.textFaint),
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
