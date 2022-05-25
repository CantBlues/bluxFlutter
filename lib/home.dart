import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'utils/network.dart';
import 'utils/eventbus.dart';
import 'dart:async';

class Landscape extends StatefulWidget {
  @override
  _LandscapeState createState() => _LandscapeState();
}

class _LandscapeState extends State<Landscape> {
  bool _ipv = ipv;
  bool _pcStatus = false;
  bool _blink = false;

  @override
  void initState() {
    super.initState();
    bus.on("netChange", (arg) {
      setState(() {
        _ipv = ipv;
      });
    });
    checkPc();
  }

  checkPc() {
    checkOnline().then(
      (value) {
        if (value) {
          setState(() {
            _pcStatus = true;
            _blink = false;
          });
        }
      },
    );
    setState(() {
      _blink = true;
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
                      checkPc();
                      int count = 0;
                      if (!_pcStatus) {
                        Timer.periodic(Duration(seconds: 10), (t) {
                          count++;
                          checkPc();
                          if (count > 5) t.cancel();
                        });
                      }
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
                                    setState(() {
                                      _pcStatus = false;
                                    });
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
                    child: Stack(
                      alignment: Alignment(1, 0.2),
                      children: [
                        ShaderMask(
                            shaderCallback: (bounds) {
                              return RadialGradient(
                                radius: _pcStatus ? .55 : .5,
                                colors: <Color>[
                                  _pcStatus
                                      ? Colors.red
                                      : Colors.yellow.shade100,
                                  Colors.red.withOpacity(0)
                                ],
                              ).createShader(bounds);
                            },
                            child: _blink
                                ? BlinkAnimation()
                                : Container(
                                    color: Colors.white,
                                    width: 50,
                                    height: 60)),
                        Image.asset("assets/denglong.png", width: 60)
                      ],
                    )),
              ),
              Align(
                  alignment: Alignment(-0.5, 0.5),
                  child: GestureDetector(
                    child: Container(
                      width: 48,
                      height: 108,
                    ),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_pcStatus)
                        Navigator.of(context).pushNamed('videoList');
                    },
                    onLongPress: () {
                      if (_pcStatus) Navigator.of(context).pushNamed('audios');
                    },
                  ))
            ],
          )),
    );
  }
}

class BlinkAnimation extends StatefulWidget {
  @override
  _BlinkAnimationState createState() => _BlinkAnimationState();
}

class _BlinkAnimationState extends State<BlinkAnimation>
    with TickerProviderStateMixin {
  late AnimationController controller;
  late Animation _color;

  @override
  void initState() {
    super.initState();
    controller = new AnimationController(
        vsync: this, duration: Duration(milliseconds: 600));
    _color = ColorTween(begin: Colors.red, end: Colors.yellow.shade200).animate(
        CurvedAnimation(
            parent: controller,
            curve: Interval(0, 0.4, curve: Curves.easeInCirc)));
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        controller.forward();
      }
    });
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Container(width: 50, height: 60, color: _color.value);
        });
  }
}
