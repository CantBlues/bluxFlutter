import 'dart:convert';
import 'dart:ui';

import 'package:blux/utils/network.dart';
import 'package:blux/v2ray/nodeCard.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class V2rayPage extends StatefulWidget {
  const V2rayPage({Key? key}) : super(key: key);

  @override
  State<V2rayPage> createState() => V2rayPageState();
}

class V2rayPageState extends State<V2rayPage> {
  List _nodes = [];
  dynamic current;
  late Future<List> _fetchData;
  bool _fwStatus = false;
  int selected = 0;
  Future<Null> _onRefresh() async {
    await Dio().get(Openwrt + "fetch?refresh=1");
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Provider.value(
        value: selected,
        child: Provider.value(
          value: this,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: FutureBuilder<List>(
                future: _fetchData,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting)
                    return Center(child: CircularProgressIndicator());
                  return Stack(
                    children: <Widget>[
                      _buildTopBg(headerHeight),
                      ListView.builder(
                        padding:
                            EdgeInsets.only(bottom: 40, top: headerHeight + 60),
                        itemCount: snap.data!.length,
                        scrollDirection: Axis.vertical,
                        itemBuilder: (context, index) => _buildListItem(index),
                      ),
                      _buildTopContent(headerHeight),
                    ],
                  );
                }),
          ),
        ),
      ),
    );
  }

  Future<List> fetchConfig() async {
    var response = await Dio().get(Openwrt + "/fetch");
    var data = jsonDecode(response.data);
    _nodes = data["nodes"];
    current = data["current"];
    _fwStatus = data["status"];
    setState(() {});
    return _nodes;
  }

  Widget _buildListItem(int index) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: NodeCard(NodeData(data: _nodes[index], index: index)),
    );
  }

  void setSelect(int val) {
    setState(() {
      selected = val;
    });
  }

  Widget _buildTopBg(double height) {
    return Container(
        alignment: Alignment.topCenter,
        child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Image(
                image: AssetImage("assets/runway.jpg"), fit: BoxFit.fitWidth)));
  }

  Widget _buildTopContent(double height) {
    return GestureDetector(
      onDoubleTap: () {
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("提示"),
                content: Text("确定切换iptables?"),
                actions: <Widget>[
                  TextButton(
                    child: Text("取消"),
                    onPressed: () => Navigator.of(context).pop(false), //关闭对话框
                  ),
                  TextButton(
                    child: Text("确定"),
                    onPressed: () {
                      Dio().get(Openwrt + "/iptable/toggle").then(((value) {
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
          duration: Duration(milliseconds: 800),
          alignment: Alignment(0, _fwStatus ? -1 : -1.5),
          child: Container(
            color: Colors.black.withAlpha(128),
            margin: EdgeInsets.all(15),
            constraints: BoxConstraints(maxHeight: height),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    current != null ? current["ps"] : "null",
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ),
                Divider(color: Colors.grey),
                !_fwStatus
                    ? Container()
                    : Padding(
                        padding: EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                                text: TextSpan(children: [
                              TextSpan(
                                  text: "addr: ",
                                  style: TextStyle(
                                      color: Colors.yellow, fontSize: 20)),
                              TextSpan(
                                  text: current["add"],
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 20))
                            ])),
                            RichText(
                                text: TextSpan(children: [
                              TextSpan(
                                  text: "port: ",
                                  style: TextStyle(
                                      color: Colors.yellow, fontSize: 20)),
                              TextSpan(
                                  text: current["port"].toString(),
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 20))
                            ])),
                            RichText(
                                text: TextSpan(children: [
                              TextSpan(
                                  text: "protocol: ",
                                  style: TextStyle(
                                      color: Colors.yellow, fontSize: 20)),
                              TextSpan(
                                  text: current["protocol"],
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 20))
                            ]))
                          ],
                        )),
                _fwStatus
                    ? Container()
                    : Padding(
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
