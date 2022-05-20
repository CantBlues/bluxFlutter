import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'utils/network.dart';
import 'utils/eventbus.dart';

class Landscape extends StatefulWidget {
  @override
  _LandscapeState createState() => _LandscapeState();
}

class _LandscapeState extends State<Landscape> {
  bool _ipv = ipv;

  @override
  void initState() {
    super.initState();
    bus.on("netChange", (arg) {
      setState(() {
        _ipv = ipv;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
          child: Center(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(child: Text("current server:${dio.options.baseUrl}")),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("IPv4/6:"),
              Switch(
                  value: _ipv,
                  onChanged: (v) {
                    switchIpv(!_ipv);
                  })
            ],
          ),
        ],
      ))),
      body: Container(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    width: double.infinity,
                    height: 700,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [
                          0,
                          .8,
                          1
                        ],
                            colors: [
                          Color.fromRGBO(117, 173, 255, 1),
                          Color.fromRGBO(253, 213, 202, 1),
                          Color.fromRGBO(255, 218, 164, 1)
                        ])),
                  )),
              Align(
                  alignment: Alignment.bottomCenter,
                  child: Image.asset("assets/landscape.png",
                      width: double.infinity)),
              Align(
                alignment: Alignment(-1.05, 0.255),
                child: GestureDetector(
                    onDoubleTap: () {
                      sendUDP("192.168.0.255");
                      remoteWake("47.104.99.3");
                    },
                    onLongPress: () {
                      showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text("提示"),
                              content: Text("您确定要关机吗?"),
                              actions: <Widget>[
                                TextButton(
                                  child: Text("取消"),
                                  onPressed: () =>
                                      Navigator.of(context).pop(false), //关闭对话框
                                ),
                                TextButton(
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
                    child: Stack(alignment: Alignment(-1.05, 0.255),children: [ShaderMask(
                        shaderCallback: (bounds) {
                          return RadialGradient(
                            radius: .8,
                            colors: <Color>[
                              Colors.red,
                              Colors.transparent.withOpacity(0)
                            ],
                          ).createShader(bounds);
                        },
                        child: Container(color:Colors.white,width:50,height:50)),Image.asset("assets/denglong.png", width: 60)],)
                    // child: Stack(children: [
                    //   Container(
                    //       width: 70,
                    //       height: 115,
                    //       alignment: Alignment.bottomCenter,
                    //       // color: Colors.red,
                    //       child: Container(width:38,height:50,decoration: BoxDecoration(color: Colors.red,shape: BoxShape.circle))),
                    //   Image.asset("assets/denglong.png", width: 60)
                    // ]),
                    ),
              ),
              Align(
                  alignment: Alignment(-0.5, 0.5),
                  child: GestureDetector(
                    child: Container(
                      width: 48,
                      height: 108,
                    ),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pushNamed('videoList'),
                    onLongPress: () =>
                        Navigator.of(context).pushNamed('audios'),
                  ))
            ],
          )),
    );
  }
}
