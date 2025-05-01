import 'package:flutter/material.dart';
import 'package:wheel_chooser/wheel_chooser.dart';
import 'dart:convert';
import 'usage/usage_utils.dart';
import 'utils/network.dart';

class TaskWidget extends StatefulWidget {
  const TaskWidget(this.name, this.left, this.tap, this.status, {super.key});

  final String name;
  final bool left;
  final bool status;
  final tap;

  @override
  State<StatefulWidget> createState() => _TaskWidgetState();
}

class _TaskWidgetState extends State<TaskWidget> {
  bool _mark = false;

  _taskTap() {
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
            shadows: const [Shadow(blurRadius: 10)],
            decorationColor: Colors.red,
            decorationThickness: 3,
            decoration: _mark ? TextDecoration.lineThrough : TextDecoration.none));
    Alignment align = widget.left ? const Alignment(-0.6, 0) : const Alignment(0.6, 0);
    return TextButton(
        onPressed: () => _taskTap(),
        style: TextButton.styleFrom(padding: const EdgeInsets.all(0)),
        child: Align(alignment: align, child: text));
  }
}

class TaskLayer extends StatefulWidget {
  const TaskLayer({super.key});

  @override
  State<StatefulWidget> createState() => _TaskLayerState();
}

class _TaskLayerState extends State<TaskLayer> {
  DateTime selectDate = DateTime.now();
  List nearDate = [];
  bool _loading = true;
  List<int> serverData = [];
  List<Map<String, dynamic>> tasks = [];

  Future tapTask(String name, bool mark) async {
    var ret = await dioLara
        .post("/api/task/mark", data: {"date": selectDate.millisecondsSinceEpoch, "name": name, "mark": mark});
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

  queryTasks(DateTime day) {
    setState(() {
      _loading = true;
    });
    dioLara.get('/api/tasktypes').then(
      (response) {
        var data = jsonDecode(response.data);
        List<Map<String, dynamic>> tasks = [];
        for (var element in data['data']) {
          tasks.add({"name": element["name"], "type_id": element["id"]});
        }
        setState(() {
          tasks = tasks;
        });
      },
    );
    dioLara.get("/api/tasks/daily/${day.millisecondsSinceEpoch}").then((response) {
      var ret = jsonDecode(response.data);
      List<int> markedTask = [];
      for (var element in ret['data']) {
        markedTask.add(element['type_id']);
      }
      setState(() {
        serverData = markedTask;
        _loading = false;
      });
    });
  }

  dateChanged(data) {
    data = DateTime.parse(data);
    queryTasks(data);
    selectDate = data;
  }

  List generateNearDate() {
    List dates = [];
    DateTime from = DateTime.now().subtract(const Duration(days: 7));

    while (from.isBefore(DateTime.now())) {
      dates.add(from.toString().substring(0, 10));
      from = from.add(const Duration(days: 1));
    }
    return dates;
  }

  @override
  void initState() {
    super.initState();
    nearDate = generateNearDate();
    queryTasks(DateTime.now());
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
      child: Scaffold(
        body: Container(
          decoration:
              const BoxDecoration(image: DecorationImage(image: AssetImage("assets/blackboard.jpg"), fit: BoxFit.fitWidth)),
          child: Column(
            children: [
              Container(height: 50),
              SizedBox(
                  height: 100,
                  child: WheelChooser(
                    itemSize: 100,
                    startPosition: nearDate.length,
                    onValueChanged: dateChanged,
                    datas: nearDate,
                    horizontal: true,
                    selectTextStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    unSelectTextStyle: const TextStyle(color: Colors.white),
                  )),
              Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          // mainAxisAlignment: MainAxisAlignment.end,
                          children: _generateTasks()))
            ],
          ),
        ),
      ),
    );
  }
}
