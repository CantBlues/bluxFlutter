import 'package:blux/kitt/theme.dart';
import 'package:blux/kitt/widgets.dart';
import 'package:blux/local/ad_notify.dart';
import 'package:blux/local/local_db.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 广告日志：记录每天看的广告（游戏 / 设备 可选自快捷名录，广告名手输），
/// 带时间戳，数据全在本地 kitt_blux.db，并支持每日固定时间提醒 + 推迟。
class AdsPage extends StatefulWidget {
  const AdsPage({super.key});

  @override
  State<AdsPage> createState() => _AdsPageState();
}

class _AdsPageState extends State<AdsPage> {
  List<String> _games = [];
  List<String> _phones = [];
  String? _selGame;
  String? _selPhone;
  final _ad = TextEditingController();
  List<Map<String, Object?>> _logs = [];
  Map<String, int> _series = {};
  Map<String, int> _top = {};
  int _today = 0;
  int _month = 0;
  bool _loading = true;
  bool _remindOn = false;
  int _hour = 21, _minute = 0;

  _load() async {
    final games = await AdRepo.games();
    final phones = await AdRepo.phones();
    final logs = await AdRepo.recentLogs();
    final series = await AdRepo.dailySeries();
    final top = await AdRepo.topGames();
    final today = await AdRepo.countOn(DateTime.now());
    final monthKey = LocalDb.key(DateTime.now()).substring(0, 7);
    final month = series.entries
        .where((e) => e.key.startsWith(monthKey))
        .fold(0, (a, b) => a + b.value);
    final (on, h, m) = await AdNotify.current();
    if (!mounted) return;
    setState(() {
      _games = games;
      _phones = phones;
      _logs = logs;
      _series = series;
      _top = top;
      _today = today;
      _month = month;
      _remindOn = on;
      _hour = h;
      _minute = m;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: KittColors.panelSoft,
        content: Text(msg,
            style: const TextStyle(fontFamily: KittStyle.mono))));
  }

  Future<void> _record() async {
    final name = _ad.text.trim();
    if (name.isEmpty) {
      _toast("请先输入广告名称");
      return;
    }
    await AdRepo.addLog(game: _selGame, phone: _selPhone, ad: name);
    _ad.clear();
    _load();
    _toast("已记录：$_selGame · $_selPhone · $name");
  }

  // ---------------------------------------------------------------- chips --
  Widget _chip(String label, bool selected, VoidCallback onTap) {
    final c = selected ? KittColors.red : KittColors.textFaint;
    return GestureDetector(
        onTap: onTap,
        child: Container(
            margin: const EdgeInsets.only(right: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                border: Border.all(color: c),
                color: selected ? KittColors.red.withOpacity(.15) : null),
            child: Text(label,
                style: KittStyle.label(
                    size: 13,
                    spacing: 1,
                    color: selected ? KittColors.text : KittColors.textDim))));
  }

  Widget _pickerRow(String label, List<String> names, String? sel,
      ValueChanged<String?> pick, VoidCallback manage) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label,
            style: KittStyle.label(size: 13, color: KittColors.amber)),
        const Spacer(),
        TextButton(
            onPressed: manage,
            child: const Text("管理", style: TextStyle(fontSize: 13))),
      ]),
      const SizedBox(height: 4),
      Wrap(children: [
        for (final n in names)
          _chip(n, sel == n, () => pick(sel == n ? null : n)),
        if (names.isEmpty)
          Text("（空，点“管理”添加）",
              style: KittStyle.body(size: 13, color: KittColors.textFaint)),
      ]),
    ]);
  }

  void _manage(bool isGame) {
    final ctrl = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(builder: (context, setDlg) {
              final names = isGame ? _games : _phones;
              return AlertDialog(
                title: Text(isGame ? "游戏名录" : "设备名录",
                    style: KittStyle.glow(size: 16)),
                content: SizedBox(
                    width: 300,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                          height: 220,
                          child: names.isEmpty
                              ? Center(
                                  child: Text("暂无条目",
                                      style: KittStyle.body(
                                          color: KittColors.textFaint)))
                              : ListView(
                                  children: [
                                    for (final n in names)
                                      Row(children: [
                                        Expanded(
                                            child: Text(n,
                                                style: KittStyle.body(size: 14))),
                                        IconButton(
                                            icon: const Icon(Icons.delete_outline,
                                                size: 20),
                                            color: KittColors.textFaint,
                                            onPressed: () async {
                                              if (isGame) {
                                                await AdRepo.removeGame(n);
                                              } else {
                                                await AdRepo.removePhone(n);
                                              }
                                              setDlg(() {});
                                              _load();
                                            }),
                                      ]),
                                  ]),
                      ),
                      TextField(
                          controller: ctrl,
                          decoration: InputDecoration(
                              labelText: isGame ? "新游戏名" : "新设备名"),
                      ),
                      const SizedBox(height: 4),
                      ElevatedButton(
                          onPressed: () async {
                            final v = ctrl.text.trim();
                            if (v.isEmpty) return;
                            if (isGame) {
                              await AdRepo.addGame(v);
                            } else {
                              await AdRepo.addPhone(v);
                            }
                            ctrl.clear();
                            setDlg(() {});
                            _load();
                          },
                          child: const Text("添加")),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("完成")),
                ],
              );
            }));
  }

  // -------------------------------------------------------------- reminder --
  void _pickTime() {
    showModalBottomSheet(
        context: context,
        backgroundColor: KittColors.panel,
        builder: (context) {
          int h = _hour, m = _minute;
          return StatefulBuilder(builder: (context, setSheet) {
            return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const KittSection("小时"),
                      const SizedBox(height: 8),
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var i = 0; i < 24; i++)
                              _chip(i.toString().padLeft(2, '0'), h == i,
                                  () => setSheet(() => h = i))
                          ]),
                      const SizedBox(height: 6),
                      const KittSection("分钟"),
                      const SizedBox(height: 8),
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var i = 0; i < 60; i += 5)
                              _chip(i.toString().padLeft(2, '0'), m == i,
                                  () => setSheet(() => m = i))
                          ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final ok = await AdNotify.ensurePermission();
                                  if (!ok) {
                                    _toast("未获得通知权限，提醒可能无法弹出");
                                  }
                                  await AdNotify.save(
                                      on: true, hour: h, min: m);
                                  setState(() {
                                    _remindOn = true;
                                    _hour = h;
                                    _minute = m;
                                  });
                                  _toast("已设定每日 "
                                      "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} 提醒");
                                },
                                child: Text("确定 · ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}"))),
                        const SizedBox(width: 10),
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("取消")),
                      ]),
                    ]));
          });
        });
  }

  Widget _reminderPanel() {
    final t =
        "${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}";
    return KittPanel(
        title: "每日提醒",
        accent: KittColors.amber,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Switch(
                value: _remindOn,
                onChanged: (v) async {
                  final ok = v ? await AdNotify.ensurePermission() : true;
                  if (v && !ok) _toast("未获得通知权限");
                  await AdNotify.save(on: v);
                  setState(() => _remindOn = v);
                }),
            const SizedBox(width: 6),
            Text(_remindOn ? "已开启" : "已关闭",
                style: KittStyle.label(
                    size: 13,
                    color: _remindOn ? KittColors.red : KittColors.textFaint)),
            const Spacer(),
            GestureDetector(
                onTap: _pickTime,
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        border: Border.all(color: KittColors.amber)),
                    child: Text("每天 $t 修改",
                        style: KittStyle.label(
                            size: 13, color: KittColors.amber, spacing: 1)))),
          ]),
          const SizedBox(height: 4),
          Text("通知上有“推迟1小时 / 推迟3小时”按钮，点击即可延后提醒。",
              style: KittStyle.body(size: 13, color: KittColors.textDim)),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () async {
                    await AdNotify.ensurePermission();
                    await AdNotify.test();
                    _toast("8 秒后会弹一条测试通知");
                  },
                  child: const Text("发一条测试通知", style: TextStyle(fontSize: 13)))),
        ]));
  }

  // ----------------------------------------------------------------- chart --
  Widget _seriesChart() {
    final keys = _series.keys.toList();
    final vals = _series.values.toList();
    final maxY = vals.isEmpty ? 4.0 : (vals.reduce((a, b) => a > b ? a : b) + 1).toDouble();
    return SizedBox(
        height: 140,
        child: BarChart(BarChartData(
            maxY: maxY,
            minY: 0,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) =>
                    FlLine(color: KittColors.grid, strokeWidth: .5)),
            barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => KittColors.panelSoft,
                    getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                        "${keys[g.x]}: ${r.toY.toInt()} 条",
                        const TextStyle(
                            color: KittColors.text,
                            fontFamily: KittStyle.mono,
                            fontSize: 12)))),
            titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        interval: 3,
                        reservedSize: 26,
                        getTitlesWidget: (x, meta) {
                          final i = x.round();
                          if (i < 0 || i >= keys.length) {
                            return const SizedBox();
                          }
                          final d = keys[i].substring(5); // MM-dd
                          return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(d,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontFamily: KittStyle.mono,
                                      color: KittColors.textDim)));
                        }))),
            barGroups: [
              for (var i = 0; i < vals.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                      toY: vals[i].toDouble(),
                      color: i == vals.length - 1
                          ? KittColors.redBright
                          : KittColors.red,
                      width: 9)
                ])
            ])));
  }

  // ------------------------------------------------------------------ list --
  Widget _logRow(Map<String, Object?> e) {
    final ts = DateTime.fromMillisecondsSinceEpoch(e['ts'] as int);
    final hm = "${ts.hour.toString().padLeft(2, '0')}:"
        "${ts.minute.toString().padLeft(2, '0')}";
    final meta = [
      (e['date'] as String).substring(5),
      hm,
      e['game'] ?? '',
      e['phone'] ?? '',
    ].where((s) => s.toString().isNotEmpty).join(" · ");
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("${e['ad']}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KittStyle.body(size: 14, color: KittColors.text)),
                Text(meta,
                    style: KittStyle.label(
                        size: 12, color: KittColors.textDim, spacing: 1)),
              ])),
          IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: KittColors.textFaint,
              onPressed: () async {
                await AdRepo.deleteLog(e['id'] as int);
                _load();
              }),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("广告日志")),
        body: GridBackdrop(
            child: SafeArea(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(14),
                        children: [
                          KittPanel(
                              title: "今日概览",
                              child: Row(children: [
                                KittGauge(
                                    value: _today.toDouble(),
                                    maxValue: 10,
                                    sub: "今日",
                                    color: KittColors.red,
                                    size: 86),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text("本月共 $_month 条",
                                              style: KittStyle.body(
                                                  size: 14,
                                                  color: KittColors.amber)),
                                          const SizedBox(height: 6),
                                          if (_top.isNotEmpty)
                                            Text("高频游戏：${_top.keys.first}",
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: KittStyle.body(
                                                    size: 13,
                                                    color:
                                                        KittColors.textDim)),
                                        ])),
                              ])),
                          const SizedBox(height: 12),
                          KittPanel(
                              title: "近 14 天",
                              accent: KittColors.cyan,
                              child: _seriesChart()),
                          const SizedBox(height: 12),
                          KittPanel(
                              title: "快速记录",
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _pickerRow("游戏", _games, _selGame,
                                        (v) => setState(() => _selGame = v),
                                        () => _manage(true)),
                                    const SizedBox(height: 4),
                                    _pickerRow("设备", _phones, _selPhone,
                                        (v) => setState(() => _selPhone = v),
                                        () => _manage(false)),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Expanded(
                                          child: TextField(
                                              controller: _ad,
                                              textInputAction:
                                                  TextInputAction.done,
                                              onSubmitted: (_) => _record(),
                                              decoration: const InputDecoration(
                                                  labelText: "广告名称")),
                                      ),
                                      const SizedBox(width: 10),
                      ElevatedButton(
                                          onPressed: _record,
                                          child: const Text("记录")),
                                    ]),
                                  ])),
                          const SizedBox(height: 12),
                          _reminderPanel(),
                          const SizedBox(height: 12),
                          KittPanel(
                              title: "最近记录",
                              accent: KittColors.green,
                              child: _logs.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Center(
                                          child: Text("还没有记录",
                                              style: KittStyle.body(
                                                  color:
                                                      KittColors.textFaint))),
                                    )
                                  : Column(
                                      children: [
                                        for (final e in _logs) _logRow(e)
                                      ],
                                    )),
                        ]))));
  }
}
