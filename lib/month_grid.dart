import 'package:flutter/material.dart';
import 'dart:math';
import 'package:hexagon/hexagon.dart';

class MonthGridPage extends StatelessWidget {
  const MonthGridPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

            return SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(12, (monthIndex) {
                  return Padding(
                    padding: EdgeInsets.only(left: horizonPadding),
                    child: MonthView(
                      monthIndex: monthIndex + 1,
                      availableHeight: cellSize,
                      padding: padding,
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

  const MonthView({super.key, required this.monthIndex, required this.availableHeight, required this.padding});

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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              child: HexagonWidget.flat(
                width: daySize,
                color: Colors.blue.shade100,
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
