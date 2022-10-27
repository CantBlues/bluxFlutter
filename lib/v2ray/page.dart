import 'dart:convert';

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
  dynamic _current;
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
      backgroundColor: Color(0xff22222b),
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
                      ListView.builder(
                        padding:
                            EdgeInsets.only(bottom: 40, top: headerHeight + 10),
                        itemCount: snap.data!.length,
                        scrollDirection: Axis.vertical,
                        itemBuilder: (context, index) => _buildListItem(index),
                      ),
                      // _buildTopBg(headerHeight),
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
    _current = data["current"];
    _fwStatus = data["status"];
    setState(() {});
    return _nodes;
  }

  Widget _buildListItem(int index) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: NodeCard(NodeData(title: _nodes[index]["ps"], index: index)),
    );
  }

  void setSelect(int val) {
    setState(() {
      selected = val;
    });
  }

  Widget _buildTopBg(double height) {
    return RoundedShadow(
      topLeftRadius: 0,
      topRightRadius: 0,
      child: Container(
        alignment: Alignment.topCenter,
        height: height,
        color: Color.fromARGB(255, 19, 37, 94),
      ),
    );
  }

  Widget _buildTopContent(double height) {
    return GestureDetector(
      onLongPress: () {
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
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            padding: EdgeInsets.all(height * .08),
            constraints: BoxConstraints(maxHeight: height),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  _current != null ? _current["ps"] : "null",
                  style: TextStyle(fontSize: 28, color: Colors.white),
                ),
                Text(
                  _fwStatus ? "firewall enable" : "firewall disable",
                  style: TextStyle(
                      fontSize: 28,
                      color: _fwStatus ? Colors.green : Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
