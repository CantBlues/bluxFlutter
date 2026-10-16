import 'package:blux/kitt/theme.dart';
import 'package:blux/kitt/widgets.dart';
import 'package:blux/local/local_db.dart';
import 'package:blux/month_grid.dart';
import 'package:flutter/material.dart';
import 'package:hexagon/hexagon.dart';

const habitIconChoices = [
  Icons.fitness_center,
  Icons.menu_book,
  Icons.self_improvement,
  Icons.local_drink,
  Icons.bedtime,
  Icons.directions_run,
  Icons.brush,
  Icons.code,
  Icons.music_note,
  Icons.edit_note,
  Icons.wc,
  Icons.pets,
];

IconData habitIconOf(HabitType h) {
  if (h.iconCode != null && h.iconFont != null) {
    try {
      return IconData(h.iconCode!, fontFamily: h.iconFont!, matchTextDirection: true);
    } catch (_) {}
  }
  return Icons.insights;
}

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  List<HabitType> habits = [];
  Set<int> done = {};
  bool _loading = true;

  _load() async {
    final list = await HabitRepo.types();
    final recorded = <int>{};
    for (final h in list) {
      if (await HabitRepo.isRecorded(h.id, DateTime.now())) recorded.add(h.id);
    }
    if (!mounted) return;
    setState(() {
      habits = list;
      done = recorded;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  _toggle(HabitType h) async {
    final now = await HabitRepo.toggleToday(h.id);
    _load();
    if (now) {
      debugPrint("habit ${h.name} recorded");
    }
  }

  _addHabit() {
    final controller = TextEditingController();
    int? picked;
    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(builder: (context, setDialog) {
              return AlertDialog(
                title: Text("新建习惯", style: KittStyle.glow(size: 16)),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: "习惯名称"),
                      autofocus: true),
                  const SizedBox(height: 14),
                  Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < habitIconChoices.length; i++)
                          GestureDetector(
                              onTap: () => setDialog(() => picked = i),
                              child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          color: picked == i
                                              ? KittColors.red
                                              : KittColors.textFaint),
                                      color: picked == i
                                          ? KittColors.red.withOpacity(.15)
                                          : Colors.transparent),
                                  child: Icon(habitIconChoices[i],
                                      size: 22,
                                      color: picked == i
                                          ? KittColors.red
                                          : KittColors.textDim)))
                      ])
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("取消")),
                  TextButton(
                      onPressed: () async {
                        if (controller.text.isEmpty) return;
                        final icon = picked == null ? null : habitIconChoices[picked!];
                        await HabitRepo.addType(controller.text,
                            iconCode: icon?.codePoint, iconFont: icon?.fontFamily);
                        if (context.mounted) Navigator.pop(context);
                        _load();
                      },
                      child: const Text("创建",
                          style: TextStyle(color: KittColors.red))),
                ],
              );
            }));
  }

  Widget _tile(HabitType h) {
    final lit = done.contains(h.id);
    return GestureDetector(
        onTap: () => _toggle(h),
        onLongPress: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HabbitRecordPage(id: h.id, name: h.name))),
        child: KittPanel(
            accent: lit ? KittColors.red : KittColors.textFaint,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              SizedBox(
                  width: 46,
                  height: 46,
                  child: HexagonWidget.pointy(
                      width: 44,
                      color: lit ? KittColors.red : KittColors.panelSoft,
                      child: Icon(habitIconOf(h),
                          size: 22, color: lit ? Colors.white : KittColors.textDim))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.name,
                            style: TextStyle(
                                fontFamily: KittStyle.mono,
                                fontSize: 17,
                                color: lit ? KittColors.text : KittColors.textDim)),
                        Text(lit ? "今日已记录" : "点按打卡",
                            style: KittStyle.label(size: 12, color: lit ? KittColors.red : KittColors.textFaint, spacing: 1)),
                      ])),
              IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: KittColors.textFaint,
                  onPressed: () async {
                    await HabitRepo.deleteType(h.id);
                    _load();
                  })
            ])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Text("习惯矩阵"),
            actions: [
              IconButton(onPressed: _addHabit, icon: const Icon(Icons.add))
            ]),
        body: GridBackdrop(
            child: SafeArea(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Padding(
                        padding: const EdgeInsets.all(14),
                        child: habits.isEmpty
                            ? Center(
                                child: Text(
                                    "暂无习惯记录\n点 + 安装一个",
                                    style: KittStyle.body(color: KittColors.textDim)))
                            : ListView(
                                children: [
                                  Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: KittSection(
                                          "今日 ${done.length}/${habits.length} 已记录",
                                          color: KittColors.amber)),
                                  for (final h in habits)
                                    Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _tile(h))
                                ])))));
  }
}
