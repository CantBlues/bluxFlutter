import 'dart:convert';
import 'dart:math';

import 'package:blux/kitt/theme.dart';
import 'package:blux/kitt/widgets.dart';
import 'package:blux/local/ad_notify.dart';
import 'package:blux/local/local_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 广告日志：每款游戏每天必须完成一次记录（今日任务），记录时只填广告
/// 名称、设备自动从“参与随机”的设备里随机指定；数据全在本地
/// kitt_blux.db；到点提醒走系统日历日程，当天全部记完自动撤回。
class AdsPage extends StatefulWidget {
  const AdsPage({super.key});

  @override
  State<AdsPage> createState() => _AdsPageState();
}

class _AdsPageState extends State<AdsPage> {
  List<String> _games = [];
  List<({String name, bool rnd})> _phones = [];
  List<Map<String, Object?>> _logs = [];
  Map<String, int> _gameDone = {}; // today: game -> log count
  Map<String, String> _assign = {}; // today: game -> designated device
  bool _loading = true;
  String? _selGame;
  String? _selPhone;
  final _ad = TextEditingController();
  bool _remindOn = false;
  int _hour = 21, _minute = 0;

  /// one designated device per game per day — rolled once and persisted in
  /// prefs, so the row and the record dialog always agree, even across
  /// restarts; games added mid-day simply get a fresh roll
  Future<Map<String, String>> _ensureAssign(
      List<String> pool, List<String> games) async {
    final p = await SharedPreferences.getInstance();
    final todayK = LocalDb.key(DateTime.now());
    final out = <String, String>{};
    try {
      final raw = p.getString('ad_assign');
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        if (j['date'] == todayK) {
          (j['map'] as Map).forEach((k, v) => out[k as String] = v as String);
        }
      }
    } catch (_) {}
    var changed = out.isNotEmpty == false;
    for (final g in games) {
      final dev = out[g];
      if (dev == null && pool.isNotEmpty) {
        out[g] = pool[Random().nextInt(pool.length)];
        changed = true;
      }
    }
    if (changed) {
      await p.setString('ad_assign', jsonEncode({'date': todayK, 'map': out}));
    }
    return out;
  }

  Future<void> _load() async {
    final games = await AdRepo.games();
    final phones = await AdRepo.phoneEntries();
    final logs = await AdRepo.recentLogs();
    final done = await AdRepo.gameCountsOn(DateTime.now());
    final pool =
        phones.where((e) => e.rnd).map((e) => e.name).toList();
    final assign = await _ensureAssign(pool, games);
    final (on, h, m) = await AdNotify.current();
    if (!mounted) return;
    setState(() {
      _games = games;
      _phones = phones;
      _logs = logs;
      _gameDone = done;
      _assign = assign;
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

  // ------------------------------------------------------------- task flow --
  /// persist a (re-rolled) designated device for today, keeping the task row
  /// and the record dialog in sync
  Future<void> _setAssign(String game, String device) async {
    _assign[game] = device;
    final p = await SharedPreferences.getInstance();
    await p.setString('ad_assign',
        jsonEncode({'date': LocalDb.key(DateTime.now()), 'map': _assign}));
  }

  Future<void> _openRecord(String game, String? device) async {
    final pool = _phones.where((e) => e.rnd).map((e) => e.name).toList();
    final res = await showDialog<({String? phone, String ad})>(
        context: context,
        builder: (ctx) {
          String? cur = device;
          final ctrl = TextEditingController();
          return StatefulBuilder(builder: (ctx, setDlg) {
            void submit() {
              final t = ctrl.text.trim();
              if (t.isEmpty) {
                _toast("请填写广告名称");
                return;
              }
              Navigator.pop(ctx, (phone: cur, ad: t));
            }

            return AlertDialog(
              title: Text("完成任务 · $game",
                  style: KittStyle.glow(size: 16)),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              "指定设备：${cur ?? "未指定（设备管理里勾选“随机”）"}",
                              style: KittStyle.body(
                                  size: 14, color: KittColors.amber))),
                      if (pool.length > 1)
                        IconButton(
                            tooltip: "换一台",
                            icon: const Icon(Icons.cached, size: 20),
                            color: KittColors.red,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setDlg(() => cur = pool[Random()
                                  .nextInt(pool.length)]);
                            }),
                    ]),
                    const SizedBox(height: 10),
                    TextField(
                        controller: ctrl,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submit(),
                        decoration: const InputDecoration(
                            labelText: "广告内容/名称")),
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("取消")),
                ElevatedButton(
                    onPressed: submit, child: const Text("完成记录")),
              ],
            );
          });
        });
    if (res == null) return;
    HapticFeedback.mediumImpact();
    if (res.phone != null && res.phone != device) {
      await _setAssign(game, res.phone!); // 重掷结果记进今天，行上同步显示
    }
    await AdRepo.addLog(game: game, phone: res.phone, ad: res.ad);
    await AdNotify.refresh(); // 可能刚好补齐了今天 → 撤回日程
    _load();
    _toast("已记录：$game · ${res.phone ?? "—"} · ${res.ad}");
  }

  Widget _taskRow(String g) {
    final c = _gameDone[g] ?? 0;
    final done = c > 0;
    final dev = _assign[g];
    return InkWell(
        onTap: () {
          if (done) {
            _toast("「$g」今天已完成，想多记几条用下面的手动补录");
            return;
          }
          _openRecord(g, dev);
        },
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 22,
                  color: done ? KittColors.green : KittColors.red),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g,
                            style: KittStyle.body(
                                    size: 15,
                                    color: done
                                        ? KittColors.textDim
                                        : KittColors.text)
                                .copyWith(
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null)),
                        Text("设备：${dev ?? "未指定"}",
                            style: KittStyle.label(
                                size: 11,
                                spacing: 1,
                                color: done
                                    ? KittColors.textFaint
                                    : KittColors.amber)),
                      ])),
              Text(done ? "已完成 ×$c" : "完成 ›",
                  style: KittStyle.label(
                      size: 12,
                      spacing: 1,
                      color: done ? KittColors.green : KittColors.red)),
            ])));
  }

  Widget _taskPanel() {
    final doneN = _games.where((g) => (_gameDone[g] ?? 0) > 0).length;
    return KittPanel(
        title: "今日任务",
        accent: KittColors.red,
        child: _games.isEmpty
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("还没有游戏。添加游戏名后，每天会自动生成“每款记一次”的任务。",
                    style: KittStyle.body(
                        size: 13, color: KittColors.textDim)),
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () => _manage(true),
                        child: const Text("添加游戏",
                            style: TextStyle(fontSize: 13)))),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("完成 $doneN/${_games.length} · 每款游戏每天记一次，"
                    "设备每天随机指定一台",
                    style: KittStyle.label(
                        size: 12, spacing: 1, color: KittColors.textDim)),
                const SizedBox(height: 4),
                for (final g in _games) _taskRow(g),
              ]));
  }

  // ------------------------------------------------------------- quick add --
  Future<void> _record() async {
    final name = _ad.text.trim();
    if (name.isEmpty) {
      _toast("请先输入广告名称");
      return;
    }
    HapticFeedback.mediumImpact();
    await AdRepo.addLog(game: _selGame, phone: _selPhone, ad: name);
    _ad.clear();
    await AdNotify.refresh();
    _load();
    _toast("已记录：${_selGame ?? "—"} · ${_selPhone ?? "—"} · $name");
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

  // --------------------------------------------------------------- manage --
  void _manage(bool isGame) {
    final ctrl = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(builder: (context, setDlg) {
              final refresh = () {
                setDlg(() {});
                _load();
              };
              return AlertDialog(
                title: Text(isGame ? "游戏名录" : "设备名录",
                    style: KittStyle.glow(size: 16)),
                content: SizedBox(
                    width: 300,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                          height: 220,
                          child: isGame
                              ? (_games.isEmpty
                                  ? Center(
                                      child: Text("暂无条目",
                                          style: KittStyle.body(
                                              color: KittColors.textFaint)))
                                  : ListView(
                                      children: [
                                        for (final n in _games)
                                          Row(children: [
                                            Expanded(
                                                child: Text(n,
                                                    style:
                                                        KittStyle.body(
                                                            size: 14))),
                                            IconButton(
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 20),
                                                color: KittColors.textFaint,
                                                onPressed: () async {
                                                  await AdRepo.removeGame(n);
                                                  refresh();
                                                }),
                                          ]),
                                      ]))
                              : (_phones.isEmpty
                                  ? Center(
                                      child: Text("暂无条目",
                                          style: KittStyle.body(
                                              color: KittColors.textFaint)))
                                  : ListView(
                                      children: [
                                        for (final e in _phones)
                                          Row(children: [
                                            Expanded(
                                                child: Text(e.name,
                                                    style:
                                                        KittStyle.body(
                                                            size: 14))),
                                            Checkbox(
                                                value: e.rnd,
                                                visualDensity:
                                                    VisualDensity.compact,
                                                activeColor: KittColors.red,
                                                onChanged: (v) async {
                                                  await AdRepo.setPhoneRnd(
                                                      e.name, v ?? false);
                                                  refresh();
                                                }),
                                            Text("随机",
                                                style: KittStyle.label(
                                                    size: 11,
                                                    color: e.rnd
                                                        ? KittColors.amber
                                                        : KittColors
                                                            .textFaint)),
                                            IconButton(
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 20),
                                                color: KittColors.textFaint,
                                                onPressed: () async {
                                                  await AdRepo.removePhone(
                                                      e.name);
                                                  refresh();
                                                }),
                                          ]),
                                      ]))),
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
                              await AdRepo.addPhone(v); // 默认参与随机
                            }
                            ctrl.clear();
                            refresh();
                          },
                          child: const Text("添加")),
                      if (!isGame)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text("新设备默认勾选“参与随机”。",
                              style: KittStyle.body(
                                  size: 12, color: KittColors.textFaint)),
                        ),
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
                                  final ok =
                                      await AdNotify.ensurePermission();
                                  if (!ok) {
                                    _toast("未获得日历权限，提醒无法生效");
                                    return;
                                  }
                                  await AdNotify.save(
                                      on: true, hour: h, min: m);
                                  setState(() {
                                    _remindOn = true;
                                    _hour = h;
                                    _minute = m;
                                  });
                                  _toast("已设定每日 "
                                      "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} 日历提醒");
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
                  if (v) {
                    final ok = await AdNotify.ensurePermission();
                    if (!ok) {
                      _toast("未获得日历权限，提醒无法生效");
                      return;
                    }
                  }
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
          Text("到点由系统日历弹提醒（比应用内闹钟可靠）；每天全部记完后，"
              "当天没响的提醒会被自动撤回。若到点没弹，检查日历 App 的通知权限。",
              style: KittStyle.body(size: 13, color: KittColors.textDim)),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () async {
                    final ok = await AdNotify.test();
                    _toast(ok
                        ? "已写入日历，约 2 分钟后弹提醒"
                        : "日历不可用：请先在系统日历中添加账户，并允许日历权限");
                  },
                  child: const Text("发一条测试日程",
                      style: TextStyle(fontSize: 13)))),
        ]));
  }

  // ------------------------------------------------------------------ list --
  Widget _recentPanel() {
    const fold = 6;
    return KittPanel(
        title: "最近记录",
        accent: KittColors.green,
        child: _logs.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: Center(
                    child: Text("还没有记录",
                        style: KittStyle.body(
                            color: KittColors.textFaint))),
              )
            : Column(children: [
                for (final e in _logs.take(fold))
                  _LogRow(entry: e, onDeleted: _load),
                if (_logs.length > fold)
                  Align(
                      alignment: Alignment.center,
                      child: TextButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdsAllPage())),
                          child: Text(
                              "查看全部记录（共 ${_logs.length} 条）›",
                              style: const TextStyle(fontSize: 13)))),
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
                          _taskPanel(),
                          const SizedBox(height: 12),
                          _recentPanel(),
                          const SizedBox(height: 12),
                          KittPanel(
                              title: "手动补录",
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _pickerRow("游戏", _games, _selGame,
                                        (v) =>
                                            setState(() => _selGame = v),
                                        () => _manage(true)),
                                    const SizedBox(height: 4),
                                    _pickerRow(
                                        "设备",
                                        _phones
                                            .map((e) => e.name)
                                            .toList(),
                                        _selPhone,
                                        (v) =>
                                            setState(() => _selPhone = v),
                                        () => _manage(false)),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Expanded(
                                          child: TextField(
                                              controller: _ad,
                                              textInputAction:
                                                  TextInputAction.done,
                                              onSubmitted: (_) =>
                                                  _record(),
                                              decoration:
                                                  const InputDecoration(
                                                      labelText:
                                                          "广告名称")),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton(
                                          onPressed: _record,
                                          child: const Text("记录")),
                                    ]),
                                  ])),
                          const SizedBox(height: 12),
                          _reminderPanel(),
                        ]))));
  }
}

/// One log line shared by the preview panel and the all-records page.
/// Today's entries get the date span in red.
class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry, required this.onDeleted});

  final Map<String, Object?> entry;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final ts = DateTime.fromMillisecondsSinceEpoch(entry['ts'] as int);
    final hm = "${ts.hour.toString().padLeft(2, '0')}:"
        "${ts.minute.toString().padLeft(2, '0')}";
    final date = entry['date'] as String;
    final isToday = date == LocalDb.key(DateTime.now());
    final rest = [
      hm,
      entry['game'] ?? '',
      entry['phone'] ?? '',
    ].where((s) => s.toString().isNotEmpty).join(" · ");
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${entry['ad']}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            KittStyle.body(size: 14, color: KittColors.text)),
                    Text.rich(TextSpan(
                        style: KittStyle.label(
                            size: 12, color: KittColors.textDim, spacing: 1),
                        children: [
                          TextSpan(
                              text: date.substring(5),
                              style: TextStyle(
                                  color: isToday
                                      ? KittColors.red
                                      : KittColors.textDim)),
                          TextSpan(text: " · $rest"),
                        ])),
                  ])),
          IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: KittColors.textFaint,
              onPressed: () async {
                await AdRepo.deleteLog(entry['id'] as int);
                // 该游戏可能因此退回未完成 → 需要重新挂今天的日程
                await AdNotify.refresh();
                onDeleted();
              }),
        ]));
  }
}

/// 全部记录页：从「最近记录」面板进入，支持下拉刷新、逐条删除。
class AdsAllPage extends StatefulWidget {
  const AdsAllPage({super.key});

  @override
  State<AdsAllPage> createState() => _AdsAllPageState();
}

class _AdsAllPageState extends State<AdsAllPage> {
  List<Map<String, Object?>> _logs = [];
  bool _loading = true;

  Future<void> _load() async {
    final logs = await AdRepo.recentLogs(limit: 500);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text(_loading ? "全部记录" : "全部记录 · ${_logs.length} 条")),
        body: GridBackdrop(
            child: SafeArea(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        color: KittColors.red,
                        onRefresh: _load,
                        child: _logs.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  Padding(
                                      padding: const EdgeInsets.all(40),
                                      child: Center(
                                          child: Text("还没有记录",
                                              style: KittStyle.body(
                                                  color:
                                                      KittColors.textFaint))),
                                )
                                ]
                              )
                            : ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(14),
                                children: [
                                  for (final e in _logs)
                                    _LogRow(entry: e, onDeleted: _load)
                                ])))));
  }
}
