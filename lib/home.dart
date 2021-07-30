import 'package:flutter/material.dart';
import 'network.dart';
import 'usage.dart';

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _toVideosPage() {
    Navigator.of(context).pushNamed('videoList');
  }

  bool _ipv = ipv;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title!),
        ),
        drawer: Drawer(
            child: Center(
                child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("IPv4/6:"),
            Switch(
                value: _ipv,
                onChanged: (v) {
                  switchIpv();
                  setState(() {
                    _ipv = !_ipv;
                  });
                })
          ],
        ))),
        body: Column(
          children: <Widget>[
            Expanded(
                child: Card(
                    child: FlatButton(
                        child: Container(
                            child: Center(child: Text('test')), height: 200),
                        onPressed: _toVideosPage,
                        shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(14.0)))),
                    margin: new EdgeInsets.all(50),
                    color: Colors.blue,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14.0)))),
                flex: 5),
            Expanded(
              child: FlatButton(
                child: Text("shut down"),
                onPressed: () => {},
                onLongPress: () {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text("提示"),
                          content: Text("您确定要关机吗?"),
                          actions: <Widget>[
                            FlatButton(
                              child: Text("取消"),
                              onPressed: () =>
                                  Navigator.of(context).pop(false), //关闭对话框
                            ),
                            FlatButton(
                              child: Text("确定"),
                              onPressed: () {
                                Navigator.of(context).pop(true); //关闭对话框
                                sendShutDown().then((ret) {
                                  if (!ret) {
                                    print("shutdown failed!");
                                    // todo  display error
                                  }
                                });
                              },
                            ),
                          ],
                        );
                      });
                },
              ),
            ),
            Expanded(
              child: FlatButton(
                child: Text("remoteWakeUp"),
                onPressed: () {
                  sendUDP("192.168.0.255");
                  remoteWake("47.104.99.3");
                  // todo show tips
                },
              ),
            ),
            Expanded(
                child: TextButton(
              child: Text("app usage"),
              onPressed: () => Navigator.of(context).pushNamed('usage'),
            ))
          ],
        ));
  }
}
