import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';

class UsageEventView extends StatefulWidget {
  const UsageEventView(this.range, this.time, this.name, this.eventTypes);
  final String name;
  final DateTimeRange range;
  final TimeOfDay time;
  final List<int> eventTypes;
  static Future<List<Map>> queryEvents(String name, DateTimeRange range,
      TimeOfDay _time, List<int> eventTypes) async {
    List<Map> result = [];
    DateTime startDate = range.start;
    DateTime endDate = range.end;
    TimeOfDay time = _time;
    DateTime start = DateTime(
        startDate.year, startDate.month, startDate.day, time.hour, time.minute);
    DateTime end = DateTime(
        endDate.year, endDate.month, endDate.day, time.hour, time.minute);
    List<EventUsageInfo> data = await UsageStats.queryEvents(start, end);
    result.add({
      "PackageName": name,
      "Event Types": eventTypes,
      "start": start,
      "end": end
    });
    for (var element in data) {
      Map eventInfo = {
        "type": element.eventType,
        "packageName": element.packageName,
        "timestamp": element.timeStamp,
        "datetime":
            DateTime.fromMillisecondsSinceEpoch(int.parse(element.timeStamp!))
      };
      if (name != "" && name != element.packageName) continue;
      if (eventTypes.length != 0 &&
          !eventTypes.contains(int.parse(element.eventType!))) continue;
      result.add(eventInfo);
    }
    return result;
  }

  @override
  _UsageEventViewState createState() => _UsageEventViewState();
}

class _UsageEventViewState extends State<UsageEventView> {
  List<Map> data = [];
  bool loading = true;

  @override
  void initState() {
    UsageEventView.queryEvents(
            widget.name, widget.range, widget.time, widget.eventTypes)
        .then(
      (value) {
        setState(() {
          data = value;
          loading = false;
        });
      },
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        child: loading
            ? Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: data.length,
                itemBuilder: ((context, index) {
                  return Text(data[index].toString());
                })));
  }
}
