import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'dart:developer';

class UsagePage extends StatefulWidget {
  UsagePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _UsagePageState createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  Future<List<AppUsageInfo>> _getAppUsage(DateTime from, DateTime to) async {
    List<AppUsageInfo> infos = await AppUsage.getAppUsage(from, to);
    return infos;
  }

  @override
  Widget build(BuildContext context) {
    DateTime startDate = DateTime(2021, 07, 18);
    DateTime endDate = new DateTime.now();
    Future<List<AppUsageInfo>> infos = _getAppUsage(startDate, endDate);
    return Scaffold(
      body: FutureBuilder<List<AppUsageInfo>>(
        future: infos,
        builder:
            (BuildContext context, AsyncSnapshot<List<AppUsageInfo>> snapshot) {
          return Center(
            child: ListView.builder(
              itemBuilder: (BuildContext context, int index) {
                return Column(
                  children: [
                    Text(snapshot.data?[index].appName ?? '',
                        style: TextStyle(color: Colors.red)),
                    Text((snapshot.data?[index]).toString())
                  ],
                );
              },
              itemCount: snapshot.data?.length,
            ),
          );
        },
      ),
    );
  }
}
