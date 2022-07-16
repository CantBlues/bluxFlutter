import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';

class UsageEventView extends StatefulWidget {
  const UsageEventView(this.range, this.time, this.name, this.eventTypes);
  final String? name;
  final DateTimeRange range;
  final TimeOfDay time;
  final List<int> eventTypes;

  @override
  _UsageEventViewState createState() => _UsageEventViewState();
}

class _UsageEventViewState extends State<UsageEventView> {
  List<Map> data = [];
  bool loading = true;
  Future<List<Map>> queryEvents() async {
    List<Map> result = [];
    DateTime startDate = widget.range.start;
    DateTime endDate = widget.range.end;
    TimeOfDay time = widget.time;
    DateTime start = DateTime(
        startDate.year, startDate.month, startDate.day, time.hour,time.minute);
    DateTime end = DateTime(endDate.year, endDate.month, endDate.day,time.hour,time.minute);
    List<EventUsageInfo> data = await UsageStats.queryEvents(start, end);
    result.add({
      "PackageName": widget.name,
      "Event Types": widget.eventTypes,
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
      if (widget.name != null && widget.name != element.packageName) continue;
      if (widget.eventTypes.length != 0 &&
          !widget.eventTypes.contains(int.parse(element.eventType!))) continue;
      result.add(eventInfo);
    }
    return result;
  }

  @override
  void initState() {
    queryEvents().then(
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
