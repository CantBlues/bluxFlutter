import 'package:blux/kitt/theme.dart';
import 'package:blux/kitt/widgets.dart';
import 'package:blux/usage/usage_utils.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/network.dart';

/// Side console: link settings for the online modules and entry points
/// into local configuration.
class DrawerView extends StatefulWidget {
  const DrawerView(this.pcOnline, this.onTaskSetting, this.onAppsSetting, {super.key});
  final bool pcOnline;
  final VoidCallback onTaskSetting;
  final VoidCallback onAppsSetting;

  @override
  State<DrawerView> createState() => _DrawerViewState();
}

class _DrawerViewState extends State<DrawerView> {
  TextEditingController? _controller;
  String? _serverAddress;

  @override
  void initState() {
    super.initState();
    _loadServerAddress();
  }

  Future<void> _loadServerAddress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? addr = prefs.getString('server_address');
    setState(() {
      _serverAddress = addr ?? Domain;
      _controller = TextEditingController(text: _serverAddress);
    });
  }

  Future<void> _saveServerAddress(String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_address', value);
    setState(() {
      _serverAddress = value;
    });
    Domain = value;
    // rebuild the online-only clients against the new address
    resetClients();
  }

  Widget _entry(IconData icon, String label, VoidCallback tap, {bool locked = false}) {
    Widget content = KittPanel(
        accent: locked ? KittColors.textFaint : KittColors.red,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 22, color: locked ? KittColors.textFaint : KittColors.red),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: KittStyle.label(size: 14, color: KittColors.text))),
          const SizedBox(width: 6),
          if (locked) Text("需联网", style: KittStyle.label(size: 12, color: KittColors.amber)),
        ]));
    return Opacity(
        opacity: locked ? .4 : 1,
        child: GestureDetector(
            onTap: locked ? null : tap,
            child: Container(height: 56, margin: const EdgeInsets.only(bottom: 10), child: content)));
  }

  Widget _linkField() {
    return Row(children: [
      Expanded(
          child: TextField(
        controller: _controller,
        style: const TextStyle(color: KittColors.text, fontFamily: KittStyle.mono, fontSize: 13),
        decoration: const InputDecoration(hintText: 'http://192.168.0.141:888/'),
        onSubmitted: (value) {
          if (value.isNotEmpty) _saveServerAddress(value);
        },
      )),
      IconButton(
          icon: const Icon(Icons.save_alt),
          onPressed: () {
            if (_controller != null && _controller!.text.isNotEmpty) {
              _saveServerAddress(_controller!.text);
            }
          })
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
        backgroundColor: KittColors.bg,
        child: GridBackdrop(
            child: SafeArea(
                child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              BlinkDot(color: widget.pcOnline ? KittColors.green : KittColors.red),
              const SizedBox(width: 10),
              Expanded(
                  child: Text("K.I.T.T. 控制台",
                      overflow: TextOverflow.ellipsis, style: KittStyle.glow(size: 15))),
            ]),
            const SizedBox(height: 24),
            Text("服务器地址（影视 / 节点 / 星空）",
                style: KittStyle.label(size: 12, color: KittColors.textDim, spacing: 1)),
            const SizedBox(height: 6),
            _linkField(),
            const SizedBox(height: 24),
            const KittSection("配置"),
            const SizedBox(height: 10),
            _entry(Icons.checklist, "任务类型", widget.onTaskSetting),
            _entry(Icons.apps, "追踪应用", widget.onAppsSetting),
            _entry(Icons.hub_outlined, "中继节点",
                () => Navigator.of(context).pushNamed("v2ray"),
                locked: !widget.pcOnline),
            const SizedBox(height: 8),
            const KittSection("维护"),
            const SizedBox(height: 10),
            _entry(Icons.sync, "立即采集使用数据", () async {
              await recordPhoneUsage(multi: true);
              if (context.mounted) Navigator.of(context).pop();
            }),
            _entry(Icons.science_outlined, "测试模块",
                () => Navigator.of(context).pushNamed("test")),
            const SizedBox(height: 20),
            Text("数据库: kitt_blux.db · 本地", style: KittStyle.label(size: 12, spacing: 1)),
            Text("状态: ${widget.pcOnline ? "链路已通" : "单机模式"}",
                style: KittStyle.label(size: 12, color: KittColors.textFaint, spacing: 1)),
          ]),
        ))));
  }
}
