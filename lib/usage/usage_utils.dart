import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:universal_platform/universal_platform.dart';
import '../utils/network.dart';

class EventHandle {
  EventHandle(this.name, this.lastEvent);
  final String name;
  int sum = 0;
  EventUsageInfo lastEvent;
  int start = 0;

  record(EventUsageInfo event) {
    lastEvent = event;
    start = int.parse(event.timeStamp!) ~/ 1000;
  }

  Map end(EventUsageInfo event) {
    Map tmp = {};
    if (lastEvent.eventType != null && lastEvent.eventType == "1") {
      int usage = int.parse(event.timeStamp!) - int.parse(lastEvent.timeStamp!);
      sum += usage;
    }
    tmp['name'] = event.packageName!;
    tmp['duration'] =
        int.parse(event.timeStamp!) - int.parse(lastEvent.timeStamp!);
    tmp['start'] = double.parse(lastEvent.timeStamp!);
    lastEvent = event;
    return tmp;
  }

  show(EventUsageInfo event) {
    lastEvent = event;
    start = int.parse(event.timeStamp!) ~/ 1000;
  }

  hide(EventUsageInfo event) {
    // when app crossing the day. but The end of day isn't handle.
    //   will change the way to handle event that crossing day.
    //    maybe using continuous events, manual divide days.

    // if (lastEvent.eventType == null) {
    //   int stamp = int.parse(event.timeStamp!);
    //   var _today = DateTime.fromMillisecondsSinceEpoch(stamp);
    //   DateTime _beigin = DateTime(_today.year, _today.month, _today.day);
    //   int timeDiff = stamp - _beigin.millisecondsSinceEpoch;
    //   sum += timeDiff;
    // }
    // except first event of today is stop. Guarantee pre-event is a starting event.
    if (lastEvent.eventType != null &&
        (lastEvent.eventType == "1" ||
            lastEvent.eventType == "15" ||
            lastEvent.eventType == "19")) {
      int usage = int.parse(event.timeStamp!) - int.parse(lastEvent.timeStamp!);
      sum += usage;
    }
    lastEvent = event;
  }
}

List handleEvents(List<EventUsageInfo> origin) {
  Map<String, EventHandle> apps = {};
  List<Map> list = [];
  origin.forEach((element) {
    int eventType = int.parse(element.eventType!);
    String packageName = element.packageName!;

    if (!apps.containsKey(packageName))
      apps[packageName] = EventHandle(packageName, EventUsageInfo());
    EventHandle app = apps[packageName]!;

    switch (eventType) {
      case 1: //ACTIVITY_RESUMED
        app.record(element);
        break;
      case 2: //ACTIVITY_PAUSED
        var map = app.end(element);
        if(map['duration'] > 1000) list.add(map);
        break;
    }
  });
  return list;
}

handleStatsPerDay(List<EventUsageInfo> origin, Map today) {
  Map<String, EventHandle> apps = {};

  origin.forEach((element) {
    // traverse events   event types : https://developer.android.com/reference/android/app/usage/UsageEvents.Event
    int eventType = int.parse(element.eventType!);
    String packageName = element.packageName!;

    // use EventHandle class to deal timestamps about single app.
    if (!apps.containsKey(packageName))
      apps[packageName] = EventHandle(packageName, EventUsageInfo());
    EventHandle app = apps[packageName]!;

    switch (eventType) {
      case 1: //ACTIVITY_RESUMED
        app.show(element);
        break;
      case 2: //ACTIVITY_PAUSED
        app.hide(element);
        break;
      case 5: //CONFIGURATION_CHANGE
        break;
      case 7: //USER_INTERACTION
        break;
      case 10: //NOTIFICATION_SEEN
        break;
      case 11: //STANDBY_BUCKET_CHANGED
        break;
      case 12: //NOTIFICATION_INTERRUPTION
        break;
      case 15: //SCREEN_INTERACTIVE
        app.show(element);
        break;
      case 16: //SCREEN_NON_INTERACTIVE
        app.hide(element);
        break;
      case 17: //KEYGUARD_SHOWN
        break;
      case 18: //KEYGUARD_HIDDEN
        break;
      case 19: //FOREGROUND_SERVICE_START
        // app.show(element);
        break;
      case 20: //FOREGROUND_SERVICE_STOP
        // app.hide(element);
        break;
      case 23: //ACTIVITY_STOPPED
        // app.hide(element);
        break;
    }
  });

  apps.forEach((key, value) {
    Map tmp = {"name": key, "usage": value.sum / 1000, "stamp": value.start};
    if (value.sum != 0) today["data"].add(tmp);
  });
}

Future<List<Map>> getUsage(bool multi) async {
  if (!UniversalPlatform.isAndroid) return [{}];
  List<Map> periodUsage = [];
  DateTime now = new DateTime.now();
  DateTime endDate = DateTime(now.year, now.month, now.day);
  DateTime startDate = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: multi ? 9 : 1));

  DateTime cur = startDate;
  while (cur.isBefore(endDate)) {
    cur = cur.add(Duration(days: 1));
    int node =
        int.parse(startDate.toString().substring(0, 10).split('-').join());
    Map today = {"node": node, "data": []};

    List<EventUsageInfo> origin = await UsageStats.queryEvents(startDate, cur);
    handleStatsPerDay(origin, today);

    periodUsage.add(today);
    startDate = startDate.add(Duration(days: 1));
  }

  return periodUsage;
}

recordPhoneUsage({bool multi = false}) async {
  if (UniversalPlatform.isAndroid) {
    if (await UsageStats.checkUsagePermission() ?? false) {
      var data = await getUsage(multi);
      dioLara
          .post("/api/phone/usages", data: data)
          .then((value) => print(value.data));
    }
    UsageStats.grantUsagePermission();
  }
}

class AppUsageView extends StatefulWidget {
  @override
  _APPUsageViewState createState() => _APPUsageViewState();
}

class _APPUsageViewState extends State<AppUsageView> {
  List _infos = ["waiting"];

  showUsage() async {
    if (!(await UsageStats.checkUsagePermission() ?? false))
      UsageStats.grantUsagePermission();
    DateTime now = DateTime.now();
    var data = await getUsage(true);
    var diff = DateTime.now().difference(now);
    print(diff);
    List output = [];
    for (var element in data) {
      output.add(element["node"]);
      for (var app in element["data"]) {
        output.add(app);
      }
    }
    setState(() {
      _infos = output;
    });
  }

  @override
  void initState() {
    showUsage();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: ListView.builder(
          itemCount: _infos.length,
          itemBuilder: ((context, index) {
            return Text(_infos[index].toString());
          })),
    );
  }
}
