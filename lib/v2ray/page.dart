import 'dart:convert';
import 'package:blux/utils/network.dart';
import 'package:blux/v2ray/nodeCard.dart';
import 'package:blux/v2ray/routerRule.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class V2rayPage extends StatelessWidget {
  const V2rayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
          decoration: const BoxDecoration(
              image: DecorationImage(
                  image: AssetImage("assets/runway.jpg"),
                  fit: BoxFit.fitWidth)),
          child: PageView(children: const [
            NodesView(tag: "instant"),
            NodesView(tag: "mark"),
            NodesView(tag: "history")
          ])),
    );
  }
}

class NodesView extends StatefulWidget {
  const NodesView({super.key, required this.tag});
  final String tag;
  @override
  State<NodesView> createState() => NodesViewState();
}

class NodesViewState extends State<NodesView> {
  // List _nodes = [];
  dynamic current;
  late Future<List> _fetchData;
  bool _fwStatus = false;
  int selected = 0;
  Future<Null> _onRefresh() async {
    await Dio().get("${Openwrt}fetch");
    _fetchData = fetchConfig();
  }

  @override
  void initState() {
    super.initState();
    _fetchData = fetchConfig();
  }

  @override
  Widget build(BuildContext context) {
    double headerHeight = MediaQuery.of(context).size.height * .25;

    return Provider.value(
      value: selected,
      child: Provider.value(
        value: this,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: FutureBuilder<List>(
              future: _fetchData,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.data == null) {
                  return const Center(
                      child: Text("Router server error",
                          style: TextStyle(fontSize: 30, color: Colors.white)));
                }
                var nodeData = [];
                // reverse marked node list
                if (widget.tag == "mark") {
                  nodeData = snap.data!.reversed.toList();
                } else {
                  nodeData = snap.data!;
                }
                return Stack(
                  children: <Widget>[
                    ListView.builder(
                      padding:
                          EdgeInsets.only(bottom: 40, top: headerHeight + 60),
                      itemCount: nodeData.length,
                      scrollDirection: Axis.vertical,
                      itemBuilder: (context, index) =>
                          _buildListItem(index, nodeData[index]),
                    ),
                    _buildTopContent(headerHeight),
                  ],
                );
              }),
        ),
      ),
    );
  }

  Future<List> fetchConfig() async {
    var response = await Dio().get("$Openwrt/fetch");
    var data = jsonDecode(response.data);
    var nodes = data["nodes"];
    current = data["current"];
    _fwStatus = data["status"];
    switch (widget.tag) {
      case "mark":
        var response = await Dio().get("${Openwrt}nodes/history");
        var data = jsonDecode(response.data);
        nodes = data;
        break;
      case "history":
        var response = await laravel.get("v2ray/nodes");
        nodes = response.data["data"];
        break;
      default:
        break;
    }

    setState(() {});
    return nodes;
  }

  Widget _buildListItem(int index, dynamic data) {
    if (widget.tag != "mark") {
      return GestureDetector(
        onLongPress: () {
          Dio().post("${Openwrt}nodes/mark", data: data);
          BotToast.showText(text: "Marked!");
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: NodeCard(NodeData(data: data, index: index)),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: NodeCard(NodeData(data: data, index: index)),
    );
  }

  void setSelect(int val) {
    setState(() {
      selected = val;
    });
  }

  Widget _buildTopContent(double height) {
    return GestureDetector(
      onLongPress: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: ((context) => RouterRules()))),
      onDoubleTap: () {
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("提示"),
                content: const Text("确定切换iptables?"),
                actions: <Widget>[
                  TextButton(
                    child: const Text("取消"),
                    onPressed: () => Navigator.of(context).pop(false), //关闭对话框
                  ),
                  TextButton(
                    child: const Text("确定"),
                    onPressed: () {
                      Dio().get("$Openwrt/iptable/toggle").then(((value) {
                        if (value.data == "ok") fetchConfig();
                      }));
                      Navigator.of(context).pop(true); //关闭对话框
                    },
                  ),
                ],
              );
            });
      },
      child: SafeArea(
        child: AnimatedAlign(
          curve: Curves.elasticOut,
          duration: const Duration(milliseconds: 800),
          alignment: Alignment(0, _fwStatus ? -1 : -1.5),
          child: Container(
            color: Colors.black.withAlpha(128),
            margin: const EdgeInsets.all(15),
            constraints: BoxConstraints(maxHeight: height),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    current != null ? current["ps"] : "null",
                    style: const TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ),
                Text(
                  widget.tag,
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                ),
                _fwStatus ? const Divider(color: Colors.grey) : Container(),
                !_fwStatus || current == null
                    ? Container()
                    : Row(
                        children: [
                          IconButton(
                              onPressed: () {
                                if (widget.tag == "instant") {
                                  Dio().get("${Openwrt}fetch?refresh=1");
                                  BotToast.showText(text: "Refreshing...");
                                }
                              },
                              icon: const Icon(Icons.refresh),
                              color: Colors.white),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 20),
                              alignment: Alignment.center,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                      text: TextSpan(children: [
                                    const TextSpan(
                                        text: "addr: ",
                                        style: TextStyle(
                                            color: Colors.yellow,
                                            fontSize: 20)),
                                    TextSpan(
                                        text: current["add"],
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 20))
                                  ])),
                                  RichText(
                                      text: TextSpan(children: [
                                    const TextSpan(
                                        text: "port: ",
                                        style: TextStyle(
                                            color: Colors.yellow,
                                            fontSize: 20)),
                                    TextSpan(
                                        text: current["port"].toString(),
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 20))
                                  ])),
                                  RichText(
                                      text: TextSpan(children: [
                                    const TextSpan(
                                        text: "protocol: ",
                                        style: TextStyle(
                                            color: Colors.yellow,
                                            fontSize: 20)),
                                    TextSpan(
                                        text: current["protocol"],
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 20))
                                  ]))
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              var data = await _fetchData;
                              // Dio().post( Openwrt + "/nodes/detect",data:{"source":widget.tag,"nodes":data});
                              Dio().post("${host}v2ray/detect/nodes",
                                  data: {"source": widget.tag, "nodes": data});
                              BotToast.showText(text: "Speed Testing...");
                            },
                            icon: const Icon(Icons.check),
                            color: Colors.white,
                          ),
                        ],
                      ),
                _fwStatus
                    ? Container()
                    : const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          "firewall disable",
                          style: TextStyle(fontSize: 28, color: Colors.red),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
