import 'package:blux/kitt/theme.dart';
import 'package:blux/kitt/widgets.dart';
import 'package:blux/local/local_db.dart';
import 'package:flutter/material.dart';
import 'package:wheel_chooser/wheel_chooser.dart';

class TaskWidget extends StatelessWidget {
  const TaskWidget(this.task, this.marked, this.tap, {super.key});

  final TaskType task;
  final bool marked;
  final Function(TaskType, bool) tap;

  @override
  Widget build(BuildContext context) {
    final color = marked ? KittColors.textFaint : KittColors.red;
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => tap(task, !marked),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(children: [
              Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                      border: Border.all(color: color),
                      color: marked ? color.withOpacity(.15) : Colors.transparent,
                      borderRadius: const BorderRadius.all(Radius.circular(3))),
                  child: marked
                      ? const Icon(Icons.check, size: 18, color: KittColors.red)
                      : null),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(task.name,
                      style: TextStyle(
                          fontFamily: KittStyle.mono,
                          fontSize: 20,
                          color: marked ? KittColors.textFaint : KittColors.text,
                          shadows: marked
                              ? null
                              : const [Shadow(color: Color(0x66FF3B30), blurRadius: 6)],
                          decoration: marked ? TextDecoration.lineThrough : null,
                          decorationColor: KittColors.red,
                          decorationThickness: 2))),
              Text("x${task.weight}",
                  style: KittStyle.label(size: 13, color: KittColors.amber)),
            ])));
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
  List<int> marked = [];
  List<TaskType> tasks = [];

  Future tapTask(TaskType task, bool mark) async {
    await TaskRepo.setMark(task.id, selectDate, mark);
    _queryTasks(selectDate);
  }

  _queryTasks(DateTime day) async {
    setState(() {
      _loading = true;
    });
    final types = await TaskRepo.types();
    final ids = await TaskRepo.markedTypeIds(day);
    if (!mounted) return;
    setState(() {
      tasks = types;
      marked = ids;
      selectDate = day;
      _loading = false;
    });
  }

  dateChanged(data) {
    _queryTasks(DateTime.parse(data));
  }

  List generateNearDate() {
    List dates = [];
    DateTime from = DateTime.now().subtract(const Duration(days: 29));
    while (!from.isAfter(DateTime.now())) {
      dates.add(from.toString().substring(0, 10));
      from = from.add(const Duration(days: 1));
    }
    return dates;
  }

  @override
  void initState() {
    super.initState();
    nearDate = generateNearDate();
    _queryTasks(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final done = marked.length;
    return Scaffold(
      body: GridBackdrop(
          child: SafeArea(
              child: Column(children: [
        const SizedBox(height: 8),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: KittPanel(
                title: "今日任务",
                trailing: IconButton(
                    icon: const Icon(Icons.settings, size: 20),
                    onPressed: () => Navigator.of(context).pushNamed("taskSetting")),
                child: Row(children: [
                  KittGauge(
                      value: done.toDouble(),
                      maxValue: tasks.isEmpty ? 1 : tasks.length.toDouble(),
                      sub: "完成",
                      size: 90),
                  Expanded(
                      child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                              "$done / ${tasks.length} 标记完成\n${selectDate.toString().substring(0, 10)}",
                              style: KittStyle.body(size: 14, color: KittColors.amber)))),
                ]))),
        SizedBox(
            height: 90,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: WheelChooser(
                    itemSize: 80,
                    startPosition: nearDate.length,
                    onValueChanged: dateChanged,
                    datas: nearDate,
                    horizontal: true,
                    selectTextStyle:
                        const TextStyle(color: KittColors.red, fontWeight: FontWeight.bold, fontFamily: KittStyle.mono),
                    unSelectTextStyle: const TextStyle(
                        color: KittColors.textFaint, fontFamily: KittStyle.mono)))),
        const SizedBox(height: 4),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: KittPanel(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: tasks.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(30),
                                child: Center(
                                    child: Text("还没有任务类型\n→ 点右上角配置",
                                        style: KittStyle.body(color: KittColors.textDim)))
                              )
                            : ListView(
                                shrinkWrap: true,
                                children: tasks
                                    .map((t) => TaskWidget(
                                        t, marked.contains(t.id), tapTask))
                                    .toList(),
                              ))),
        )
      ]))),
    );
  }
}
