import 'package:blux/testpage.dart';
import 'package:flutter/material.dart';
import 'utils/network.dart';

class DrawerView extends StatelessWidget {
  const DrawerView(this.ipv, this.pcStatus);
  final bool ipv;
  final bool pcStatus;
  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: Container(
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
                  child: !ipv
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
                      value: ipv,
                      onChanged: (v) {
                        switchIpv(!ipv);
                      })
                ],
              ),
            ),
            Cave(
                TextButton(
                  child: Text("Task Types Setting",
                      style: TextStyle(fontSize: 15, color: Colors.white70)),
                  onPressed: () => pcStatus
                      ? Navigator.of(context).pushNamed("taskSetting")
                      : null,
                ),
                color: Colors.deepPurple),
            Cave(
                TextButton(
                  child: Text("UsageStat Apps Setting",
                      style: TextStyle(fontSize: 15, color: Colors.white70)),
                  onPressed: () => pcStatus
                      ? Navigator.of(context).pushNamed("usage_edit_apps")
                      : null,
                ),
                color: Colors.deepPurple),
            Cave(
                TextButton(
                    child: Text("Test Module",
                        style: TextStyle(fontSize: 15, color: Colors.white70)),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: ((context) => TestPage())))),
                color: Colors.deepPurple)
          ],
        )),
        Container(height: 50)
      ]),
      decoration: BoxDecoration(
          image: DecorationImage(
              fit: BoxFit.fill, image: AssetImage("assets/drawer.png"))),
    ));
  }
}

class Cave extends StatelessWidget {
  const Cave(this.widget, {this.color})
      : _color = (color != null) ? color : Colors.deepOrange;
  final Widget widget;
  final Color? color;
  final Color? _color;

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 60,
        width: double.infinity,
        margin: EdgeInsets.only(left: 30, top: 10, right: 30, bottom: 10),
        decoration: BoxDecoration(
            color: _color,
            borderRadius: BorderRadius.all(Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black,
                  blurStyle: BlurStyle.outer,
                  blurRadius: 10)
            ]),
        child: widget);
  }
}
