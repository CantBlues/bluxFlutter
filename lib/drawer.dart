import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/network.dart';

class DrawerView extends StatefulWidget {
  const DrawerView(this.ipv, this.pcStatus, {super.key});
  final bool ipv;
  final bool pcStatus;

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
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: Container(
      decoration: const BoxDecoration(
          image: DecorationImage(
              fit: BoxFit.fill, image: AssetImage("assets/drawer.png"))),
      child: Column(children: [
        Container(
            alignment: Alignment(-1, 0.3),
            constraints: BoxConstraints(minHeight: 300),
            child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                  color: Color.fromARGB(255, 255, 206, 111)),
              margin: EdgeInsets.only(left: 25),
              child: Align(
                  alignment: Alignment.bottomCenter,
                  child: !widget.ipv
                      ? SizedBox(
                          height: 60,
                          width: 120,
                          child: Image.asset("assets/me.png"))
                      : SizedBox(
                          width: 120,
                          child: Align(
                              alignment: Alignment(0.6, 1.2),
                              child: Image.asset("assets/cat.png", width: 50)),
                        )),
              width: 120,
              height: 80,
            )),
        // 新增服务器地址设置入口
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              const Text('服务器地址:', style: TextStyle(color: Colors.white)),
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: '输入服务器地址',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: UnderlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) _saveServerAddress(value);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.save, color: Colors.white),
                onPressed: () {
                  if (_controller != null && _controller!.text.isNotEmpty) {
                    _saveServerAddress(_controller!.text);
                  }
                },
              )
            ],
          ),
        ),
        Expanded(
            child: Column(
          verticalDirection: VerticalDirection.up,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Cave(
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 20),
                  Text(
                    "IPv4/6",
                    style: TextStyle(fontSize: 15),
                  ),
                  Expanded(child: Container()),
                  Switch(
                      value: widget.ipv,
                      onChanged: (v) {
                        switchIpv(!widget.ipv);
                      })
                ],
              ),
            ),
            Cave(
                TextButton(
                  child: Text("Task Types Setting",
                      style: TextStyle(fontSize: 15, color: Colors.white70)),
                  onPressed: () => widget.pcStatus
                      ? Navigator.of(context).pushNamed("taskSetting")
                      : null,
                ),
                color: Colors.deepPurple),
            Cave(
                TextButton(
                  child: Text("UsageStat Apps Setting",
                      style: TextStyle(fontSize: 15, color: Colors.white70)),
                  onPressed: () => widget.pcStatus
                      ? Navigator.of(context).pushNamed("usage_edit_apps")
                      : null,
                ),
                color: Colors.deepPurple),
            Cave(
                TextButton(
                    child: Text("Test Module",
                        style: TextStyle(fontSize: 15, color: Colors.white70)),
                    onPressed: () => Navigator.of(context).pushNamed("test")),
                color: Colors.deepPurple),
            Cave(
                TextButton(
                    child: Text("Nodes",
                        style: TextStyle(fontSize: 15, color: Colors.white70)),
                    onPressed: () => Navigator.of(context).pushNamed("v2ray")),
                color: Colors.blue)
          ],
        )),
        Container(height: 50)
      ]),
    ));
  }
}

class Cave extends StatelessWidget {
  const Cave(this.widget, {super.key, this.color})
      : _color = (color != null) ? color : Colors.deepOrange;
  final Widget widget;
  final Color? color;
  final Color? _color;

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 60,
        width: double.infinity,
        margin: const EdgeInsets.only(left: 30, top: 10, right: 30, bottom: 10),
        decoration: BoxDecoration(
            color: _color,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black,
                  blurStyle: BlurStyle.outer,
                  blurRadius: 10)
            ]),
        child: widget);
  }
}
