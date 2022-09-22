import 'package:flutter/material.dart';
import 'dart:convert';
import 'usage/usage_utils.dart';
import 'utils/network.dart';

class TaskWidget extends StatefulWidget {
  const TaskWidget(this.name, this.left, this.tap, this.status);

  final String name;
  final bool left;
  final bool status;
  final tap;

  @override
  State<StatefulWidget> createState() => _TaskWidgetState();
}

class _TaskWidgetState extends State<TaskWidget> {
  bool _mark = false;

  _taskTap(e) {
    widget.tap(widget.name, !_mark).then((e) {
      setState(() {
        _mark = !_mark;
      });
    });
  }

  @override
  void initState() {
    setState(() {
      _mark = widget.status;
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TaskWidget oldWidget) {
    setState(() {
      _mark = widget.status;
    });
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    var text = Text(widget.name,
        style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: _mark ? Colors.white54 : Colors.white,
            shadows: [Shadow(blurRadius: 10)],
            decorationColor: Colors.red,
            decorationThickness: 3,
            decoration:
                _mark ? TextDecoration.lineThrough : TextDecoration.none));
    Alignment align = widget.left ? Alignment(-0.6, 0) : Alignment(0.6, 0);
    return Align(
        alignment: align, child: Listener(child: text, onPointerUp: _taskTap));
  }
}

class TaskLayer extends StatefulWidget {
  TaskLayer({Key? key, this.clearBlur}) : super(key: key);
  final clearBlur;
  @override
  State<StatefulWidget> createState() => _TaskLayerState();
}

class _TaskLayerState extends State<TaskLayer> {
  late DateTime today;
  late DateTime preDay;
  bool yesterday = false;
  bool _loading = true;
  List<int> serverData = [];
  List<Map<String, dynamic>> tasks = [];

  @override
  void deactivate() {
    widget.clearBlur();
    super.deactivate();
  }

  Future tapTask(String name, bool mark) async {
    var date = yesterday ? preDay : today;
    var ret = await dioLara.post("/api/task/mark", data: {
      "date": date.millisecondsSinceEpoch,
      "name": name,
      "mark": mark
    });
    return ret;
  }

  List<Widget> _generateTasks() {
    List<Widget> ret = [];
    bool left = false;
    for (var task in tasks) {
      var marked = serverData.contains(task["type_id"]) ? true : false;
      ret.add(TaskWidget(task["name"], !left, tapTask, marked));
      left = !left;
    }
    return ret;
  }

  Widget dateTag(int day) {
    bool big = (yesterday && (day == 1)) || (!yesterday && (day == 0));
    return Expanded(
        child: Center(
            child: Listener(
      child: Container(
          padding: EdgeInsets.only(bottom: big ? 20 : 0),
          child: Text(
              day == 1
                  ? "${preDay.month}/${preDay.day}"
                  : "${today.month}/${today.day}",
              style: TextStyle(
                fontSize: big ? 30 : 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 10, color: Colors.white)],
              ))),
      onPointerUp: (event) {
        setState(() {
          yesterday = day == 1 ? true : false;
        });
        queryTasks(yesterday ? preDay : today);
      },
    )));
  }

  queryTasks(DateTime day) {
    setState(() {
      _loading = true;
    });
    dioLara.get('/api/tasktypes').then(
      (response) {
        var data = jsonDecode(response.data);
        List<Map<String, dynamic>> _tasks = [];
        for (var element in data['data']) {
          _tasks.add({"name": element["name"], "type_id": element["id"]});
        }
        setState(() {
          tasks = _tasks;
        });
      },
    );
    dioLara
        .get("/api/tasks/daily/" + day.millisecondsSinceEpoch.toString())
        .then((response) {
      var ret = jsonDecode(response.data);
      List<int> _markedTask = [];
      for (var element in ret['data']) {
        _markedTask.add(element['type_id']);
      }
      setState(() {
        serverData = _markedTask;
        _loading = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    today = DateTime.now();
    preDay = today.subtract(Duration(days: 1));
    queryTasks(today);
    // check whether need collect UsageStats
    dioLara.get("/api/phone/usages/recently/node").then((value) {
      var data = jsonDecode(value.data);
      if (data["data"].length == 9) return;
      recordPhoneUsage(multi: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: ThemeData(fontFamily: "ShadowsIntoLight"),
        child: GestureDetector(
            onDoubleTap: () {
              Navigator.of(context).pop();
              widget.clearBlur();
            },
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  Container(
                      height: 100,
                      child: Row(
                        children: [
                          yesterday
                              ? Expanded(child: Container())
                              : Container(),
                          dateTag(
                              1), // this params means subtract one day from 'today'
                          dateTag(0),
                          yesterday ? Container() : Expanded(child: Container())
                        ],
                      )),
                  Expanded(
                      child: _loading
                          ? Center(child: CircularProgressIndicator())
                          : Padding(
                              padding: EdgeInsets.only(bottom: 50),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: _generateTasks())))
                ],
              ),
            )));
  }
}
