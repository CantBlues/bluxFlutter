import 'dart:async';
import 'package:blux/drawer.dart';
import 'package:blux/kitt/theme.dart';
import 'package:blux/kitt/widgets.dart';
import 'package:blux/local/local_db.dart';
import 'package:blux/usage/usage_utils.dart';
import 'package:flutter/material.dart';
import 'utils/network.dart';
import 'package:usage_stats/usage_stats.dart';

/// Kept for the sky field: it locks/unlocks the swipeable star map.
class LockProvider with ChangeNotifier {
  bool lock = true;
  toggle() {
    lock = !lock;
    notifyListeners();
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => const Home();
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _clock;
  Timer? _ping;
  DateTime _now = DateTime.now();
  bool _pcOnline = false;
  bool _checking = false;

  // cluster readouts
  int _taskTotal = 0;
  int _taskDone = 0;
  int _habitTotal = 0;
  int _habitDone = 0;
  int _streak = 0;
  int _adCount = 0;
  double _usageHours = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      setState(() => _now = DateTime.now());
    });
    _checkPc();
    _ping = Timer.periodic(const Duration(seconds: 60), (_) => _checkPc());
    _loadLocal();
    // opportunistic collection into the local db while on this page
    Future.microtask(() async {
      try {
        if (await UsageStats.checkUsagePermission() ?? false) {
          await recordPhoneUsage();
          _loadLocal();
        }
      } catch (e) {
        print(e);
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _ping?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPc();
      _loadLocal();
    }
  }

  _checkPc() async {
    if (_checking) return;
    _checking = true;
    try {
      final v = await checkOnline().timeout(const Duration(seconds: 6));
      if (mounted) setState(() => _pcOnline = v);
    } catch (_) {
      if (mounted) setState(() => _pcOnline = false);
    }
    _checking = false;
  }

  _loadLocal() async {
    try {
      final types = await TaskRepo.types();
      final marked = await TaskRepo.markedTypeIds(DateTime.now());
      final habits = await HabitRepo.types();
      final habitDone = await HabitRepo.recordedTodayCount();
      final streak = await TaskRepo.streak();
      final adCount = await AdRepo.countOn(DateTime.now());
      final yesterday = await UsageRepo.dayTotal(
          LocalDb.key(DateTime.now().subtract(const Duration(days: 1))));
      if (!mounted) return;
      setState(() {
        _taskTotal = types.length;
        _taskDone = marked.length;
        _habitTotal = habits.length;
        _habitDone = habitDone;
        _streak = streak;
        _adCount = adCount;
        _usageHours = yesterday / 3600;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _open(String route, {Object? args}) async {
    await Navigator.of(context).pushNamed(route, arguments: args);
    _loadLocal();
  }

  Widget _lamp(bool on, String text, {Color color = KittColors.red}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      on
          ? BlinkDot(color: color, size: 7)
          : Container(width: 7, height: 7, color: Colors.grey),
      const SizedBox(width: 8),
      Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KittStyle.label(size: 12, color: KittColors.textDim)),
    ]);
  }

  Widget _header() {
    final time =
        "${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}";
    final date =
        "${_now.year}.${_now.month.toString().padLeft(2, '0')}.${_now.day.toString().padLeft(2, '0')}";
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          IconButton(
              icon: const Icon(Icons.developer_board, color: KittColors.red),
              onPressed: () => _scaffoldKey.currentState?.openDrawer()),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("K.I.T.T.", style: KittStyle.glow(size: 20)),
            Text("个人助理协议",
                style: KittStyle.label(size: 12, color: KittColors.amber, spacing: 4)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(time, style: KittStyle.value(size: 22, color: KittColors.text)),
            Text(date, style: KittStyle.label(size: 12)),
          ]),
        ]));
  }

  Widget _cluster() {
    return KittPanel(
        title: "今日仪表盘",
        trailing:
            Text("连续 $_streak 天", style: KittStyle.label(size: 13, color: KittColors.amber)),
        child: LayoutBuilder(builder: (context, c) {
          final gs = ((c.maxWidth - 20) / 3).clamp(60.0, 104.0);
          return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            KittGauge(
                value: _taskDone.toDouble(),
                maxValue: _taskTotal == 0 ? 1 : _taskTotal.toDouble(),
                sub: "任务",
                color: KittColors.red,
                size: gs),
            KittGauge(
                value: _habitDone.toDouble(),
                maxValue: _habitTotal == 0 ? 1 : _habitTotal.toDouble(),
                sub: "习惯",
                color: KittColors.amber,
                size: gs),
            KittGauge(
                value: double.parse(_usageHours.toStringAsFixed(1)),
                maxValue: 12,
                unit: "时",
                sub: "屏幕",
                color: KittColors.cyan,
                size: gs),
          ]);
        }));
  }

  List<Widget> _modules() {
    final offline = !_pcOnline;
    return [
      KittTile(
          title: "每日任务",
          subtitle: "今日 $_taskDone/$_taskTotal",
          icon: Icons.checklist,
          onTap: () => _open("tasks")),
      KittTile(
          title: "习惯打卡",
          subtitle: "今日 $_habitDone/$_habitTotal",
          icon: Icons.insights,
          accent: KittColors.amber,
          onTap: () => _open("habits")),
      KittTile(
          title: "广告日志",
          subtitle: "今日 $_adCount 条",
          icon: Icons.play_circle_outline,
          accent: const Color(0xFFFF7A3C),
          onTap: () => _open("ads")),
      KittTile(
          title: "数据分析",
          subtitle: "贡献 / 平衡",
          icon: Icons.pie_chart_outline,
          accent: KittColors.cyan,
          onTap: () => _open("billboard")),
      KittTile(
          title: "屏幕统计",
          subtitle: "使用时间线",
          icon: Icons.timeline,
          accent: KittColors.green,
          onTap: () => _open("usage")),
      KittTile(
          title: "影视库",
          subtitle: "视频课程",
          icon: Icons.movie_creation_outlined,
          disabled: offline,
          onTap: () => _open("videoList")),
      KittTile(
          title: "听力工坊",
          subtitle: "听力练习",
          icon: Icons.audiotrack,
          disabled: offline,
          onTap: () => _open("audios")),
      KittTile(
          title: "中继节点",
          subtitle: "路由器控制",
          icon: Icons.hub_outlined,
          accent: KittColors.amber,
          disabled: offline,
          onTap: () => _open("v2ray")),
      KittTile(
          title: "星空连线",
          subtitle: "星座挑战",
          icon: Icons.star,
          accent: KittColors.cyan,
          disabled: offline,
          onTap: () => _open("stars")),
      KittTile(
          title: "登月图鉴",
          subtitle: "月相图集",
          icon: Icons.nights_stay,
          accent: KittColors.cyan,
          disabled: offline,
          onTap: () => _open("moon")),
    ];
  }

  Widget _vehicleBay() {
    return KittPanel(
        title: "PC 控制",
        accent: KittColors.amber,
        child: Row(children: [
          Expanded(
              child: Text(
                  _pcOnline
                      ? "主机已响应，远程系统就绪。"
                      : "无响应。可用唤醒脉冲把它叫醒。",
                  style: KittStyle.body(size: 13, color: KittColors.textDim))),
          IconButton(
              tooltip: "唤醒",
              icon: const Icon(Icons.power_outlined),
              onPressed: () {
                sendUDP("192.168.0.255");
                _checkPc();
                int n = 0;
                Timer.periodic(const Duration(seconds: 10), (t) async {
                  await _checkPc();
                  if (_pcOnline || ++n > 18) t.cancel();
                });
              }),
          IconButton(
              tooltip: "关机",
              icon: const Icon(Icons.power_settings_new, color: KittColors.red),
              onPressed: _pcOnline ? () => _confirmShutDown() : null),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        drawer: DrawerView(_pcOnline, () => _open("taskSetting"), () => _open("usage_edit_apps")),
        body: GridBackdrop(
            child: SafeArea(
                child: Column(children: [
          _header(),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const KittScanner(height: 26)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                    child: _lamp(_pcOnline,
                        "链路: PC ${_pcOnline ? "在线" : "离线"}")),
                Expanded(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [_lamp(true, "核心: 本地", color: KittColors.green)])),
              ])),
          const SizedBox(height: 6),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _cluster()),
          Expanded(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const KittSection("功能模块"),
                    const SizedBox(height: 10),
                    GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.35,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        children: _modules()),
                    const SizedBox(height: 14),
                    const KittSection("车载终端"),
                    const SizedBox(height: 10),
                    _vehicleBay(),
                  ]))),
        ]))));
  }

  _confirmShutDown() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("关机序列"),
            content: const Text("确定要关闭远端主机吗?"),
            actions: <Widget>[
              TextButton(
                child: const Text("取消"),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text("执行", style: TextStyle(color: KittColors.red)),
                onPressed: () {
                  Navigator.of(context).pop(true);
                  setState(() => _pcOnline = false);
                  sendShutDown().then((ret) {
                    if (!ret) print("shutdown failed!");
                  });
                },
              ),
            ],
          );
        });
  }
}
