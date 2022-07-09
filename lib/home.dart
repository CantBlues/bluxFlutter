import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'utils/network.dart';
import 'utils/eventbus.dart';
import 'dart:async';
import 'billboard.dart';
import 'drawer.dart';

class Landscape extends StatefulWidget {
  @override
  _LandscapeState createState() => _LandscapeState();
}

class _LandscapeState extends State<Landscape> with WidgetsBindingObserver {
  bool _ipv = ipv;
  bool _pcStatus = false;
  bool _blink = false;
  double _blurDeep = 1;
  double _dragPos = 0;
  double _dragStartPos = 0;
  bool _draging = false; // maybe its useless

  @override
  void initState() {
    super.initState();
    bus.on("netChange", (arg) {
      setState(() {
        _ipv = ipv;
      });
    });
    checkPc();
    dioLara.get("/");
    listenNetwork();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkPc();
  }

  checkPc() {
    checkOnline().then((value) {
      if (value) {
        setState(() {
          _pcStatus = true;
          _blink = false;
        });
      }
      setState(() {
        _blink = false;
      });
    }, onError: (e) {
      setState(() {
        _blink = false;
      });
    });
    setState(() {
      _blink = true;
    });
  }

  _showTask() {
    if (_pcStatus)
      showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) {
            return TaskLayer(clearBlur: _clearBlur);
          });
  }

  _showBillboard() {
    if (_pcStatus)
      showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) {
            return Billboard();
          });
  }

  _clearBlur() {
    setState(() {
      _blurDeep = 0;
      _draging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DrawerView(_ipv, _pcStatus),
      body: Stack(children: [
        Container(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      width: double.infinity,
                      height: 800,
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
                // background image
                Align(
                    alignment: Alignment.bottomCenter,
                    child: Image.asset("assets/landscape.png",
                        width: double.infinity)),
                // billboard tap to show contributions layer.
                Align(
                    alignment: Alignment(1, 0.5),
                    child: SizedBox(
                        width: 150,
                        height: 160,
                        child: GestureDetector(
                          onTap: () => _showBillboard(),
                        ))),
                // denglong
                Align(
                  alignment: Alignment(-1.05, 0.255),
                  child: GestureDetector(
                      onDoubleTap: () {
                        sendUDP("192.168.0.255");
                        remoteWake("47.104.99.3");
                        checkPc();
                        int count = 0;
                        if (!_pcStatus) {
                          Timer.periodic(Duration(seconds: 30), (t) {
                            count++;
                            checkPc();
                            if (count > 2) t.cancel();
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
                                    onPressed: () => Navigator.of(context)
                                        .pop(false), //关闭对话框
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
                // window tap to enter video list page
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
                        if (_pcStatus)
                          Navigator.of(context).pushNamed('audios');
                      },
                    )),
                Align(
                    alignment: Alignment(0.9, -0.7),
                    child: GestureDetector(
                        child: Container(width: 200, height: 80),
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            Navigator.of(context).pushNamed("usage")))
              ],
            )),
        _draging
            ? BackdropFilter(
                child: Container(),
                filter: ImageFilter.blur(sigmaX: _blurDeep, sigmaY: _blurDeep))
            : Container(),
        Align(
            alignment: Alignment.bottomCenter,
            child: Container(
                height: 150,
                child: GestureDetector(
                  onHorizontalDragStart: (e) {
                    setState(() {
                      _draging = true;
                    });
                    _dragStartPos = e.globalPosition.dx;
                  },
                  onHorizontalDragEnd: (e) {
                    if (_dragPos > 100 || _blurDeep < 5) {
                      setState(() {
                        _draging = false;
                        _blurDeep = 0;
                      });
                    } else {
                      _showTask();
                    }
                  },
                  onHorizontalDragUpdate: (e) {
                    _dragPos = e.globalPosition.dx;
                    var tmp = _dragStartPos - _dragPos;
                    setState(() {
                      _blurDeep = tmp / 20;
                    });
                  },
                ))),
      ]),
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

class TaskWidget extends StatefulWidget {
  const TaskWidget(this.name, this.left, this.tap, this.status);

  final String name;
  final bool left;
  final bool status;
  final tap;

  @override
  State<StatefulWidget> createState() => _TaskWidgetState();
}

class _TaskWidgetState extends State<TaskWidget> {
  bool _mark = false;

  _taskTap(e) {
    widget.tap(widget.name, !_mark).then((e) {
      setState(() {
        _mark = !_mark;
      });
    });
  }

  @override
  void initState() {
    setState(() {
      _mark = widget.status;
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TaskWidget oldWidget) {
    setState(() {
      _mark = widget.status;
    });
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    var text = Text(widget.name,
        style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: _mark ? Colors.white54 : Colors.white,
            shadows: [Shadow(blurRadius: 10)],
            decorationColor: Colors.red,
            decorationThickness: 3,
            decoration:
                _mark ? TextDecoration.lineThrough : TextDecoration.none));
    Alignment align = widget.left ? Alignment(-0.6, 0) : Alignment(0.6, 0);
    return Align(
        alignment: align, child: Listener(child: text, onPointerUp: _taskTap));
  }
}

class TaskLayer extends StatefulWidget {
  TaskLayer({Key? key, this.clearBlur}) : super(key: key);
  final clearBlur;
  @override
  State<StatefulWidget> createState() => _TaskLayerState();
}

class _TaskLayerState extends State<TaskLayer> {
  late DateTime today;
  late DateTime preDay;
  bool yesterday = false;
  bool _loading = true;
  List<int> serverData = [];
  List<Map<String, dynamic>> tasks = [];

  @override
  void deactivate() {
    widget.clearBlur();
    super.deactivate();
  }

  Future tapTask(String name, bool mark) async {
    var date = yesterday ? preDay : today;
    var ret = await dioLara.post("/api/task/mark", data: {
      "date": date.millisecondsSinceEpoch,
      "name": name,
      "mark": mark
    });
    return ret;
  }

  List<Widget> _generateTasks() {
    List<Widget> ret = [];
    bool left = false;
    for (var task in tasks) {
      var marked = serverData.contains(task["type_id"]) ? true : false;
      ret.add(TaskWidget(task["name"], !left, tapTask, marked));
      left = !left;
    }
    return ret;
  }

  Widget dateTag(int day) {
    bool big = (yesterday && (day == 1)) || (!yesterday && (day == 0));
    return Expanded(
        child: Center(
            child: Listener(
      child: Container(
          padding: EdgeInsets.only(bottom: big ? 20 : 0),
          child: Text(
              day == 1
                  ? "${preDay.month}/${preDay.day}"
                  : "${today.month}/${today.day}",
              style: TextStyle(
                fontSize: big ? 30 : 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 10, color: Colors.white)],
              ))),
      onPointerUp: (event) {
        setState(() {
          yesterday = day == 1 ? true : false;
        });
        queryTasks(yesterday ? preDay : today);
      },
    )));
  }

  queryTasks(DateTime day) {
    setState(() {
      _loading = true;
    });
    dioLara.get('/api/tasktypes').then(
      (response) {
        var data = jsonDecode(response.data);
        List<Map<String, dynamic>> _tasks = [];
        for (var element in data['data']) {
          _tasks.add({"name": element["name"], "type_id": element["id"]});
        }
        setState(() {
          tasks = _tasks;
        });
      },
    );
    dioLara
        .get("/api/tasks/daily/" + day.millisecondsSinceEpoch.toString())
        .then((response) {
      var ret = jsonDecode(response.data);
      List<int> _markedTask = [];
      for (var element in ret['data']) {
        _markedTask.add(element['type_id']);
      }
      setState(() {
        serverData = _markedTask;
        _loading = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    today = DateTime.now();
    preDay = today.subtract(Duration(days: 1));
    queryTasks(today);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: ThemeData(fontFamily: "ShadowsIntoLight"),
        child: GestureDetector(
            onDoubleTap: () {
              Navigator.of(context).pop();
              widget.clearBlur();
            },
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  Container(
                      height: 100,
                      child: Row(
                        children: [
                          yesterday
                              ? Expanded(child: Container())
                              : Container(),
                          dateTag(
                              1), // this params means subtract one day from 'today'
                          dateTag(0),
                          yesterday ? Container() : Expanded(child: Container())
                        ],
                      )),
                  Expanded(
                      child: _loading
                          ? Center(child: CircularProgressIndicator())
                          : Padding(
                              padding: EdgeInsets.only(bottom: 50),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: _generateTasks())))
                ],
              ),
            )));
  }
}
