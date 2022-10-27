import 'dart:math';

import 'package:blux/utils/network.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './page.dart';

class NodeData {
  final String title;
  final int index;
  NodeData({this.title = "", this.index = 0});
}

class NodeCard extends StatefulWidget {
  const NodeCard(this.nodeData);
  final NodeData nodeData;

  @override
  _NodeCardState createState() => _NodeCardState();
}

class _NodeCardState extends State<NodeCard> {
  final double nominalHeightClosed = 80;
  final double nominalHeightOpen = 300;
  bool _wasOpen = false;

  @override
  Widget build(BuildContext context) {
    //Determine current fill level, based on _fillTween
    final selected = context.watch<V2rayPageState>().selected;
    if (selected != widget.nodeData.index) _wasOpen = false;
    final wasOpen = _wasOpen && selected == widget.nodeData.index;

    double cardHeight = wasOpen ? nominalHeightOpen : nominalHeightClosed;

    return GestureDetector(
      onTap: _handleTap,
      //Use an animated container so we can easily animate our widget height
      child: AnimatedContainer(
          curve: !wasOpen ? ElasticOutCurve(.9) : Curves.elasticOut,
          duration: Duration(milliseconds: !wasOpen ? 800 : 1200),
          height: cardHeight,
          //Wrap content in a rounded shadow widget, so it will be rounded on the corners but also have a drop shadow

          child: RoundedShadow.fromRadius(
            12,
            child: Container(
              color: Color(0xff303238),
              child: Stack(fit: StackFit.expand, children: <Widget>[
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  //Wrap content in a ScrollView, so there's no errors on over scroll.
                  child: SingleChildScrollView(
                    //We don't actually want the scrollview to scroll, disable it.
                    physics: NeverScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        SizedBox(height: 24),
                        //Top Header Row
                        _buildTopContent(),
                        //Spacer
                        SizedBox(height: 12),
                        //Bottom Content, use AnimatedOpacity to fade
                        AnimatedOpacity(
                          duration:
                              Duration(milliseconds: wasOpen ? 1000 : 500),
                          curve: Curves.easeOut,
                          opacity: wasOpen ? 1 : 0,
                          //Bottom Content
                          child: _buildMainContent(),
                        ),
                      ],
                    ),
                  ),
                )
              ]),
            ),
          )),
    );
  }

  Widget _buildMainContent() {
    return Container(
        child: ElevatedButton(
      child: Text("Go"),
      onPressed: () {
        Dio().get(Openwrt + "change?target=${widget.nodeData.index}").then(
              (value) => context.read<V2rayPageState>().fetchConfig(),
            );
      },
    ));
  }

  Row _buildTopContent() {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: Text(widget.nodeData.title,
              style: TextStyle(fontFamily: "Poppins", color: Colors.white)),
        ),
        Expanded(
          flex: 1,
          child: Column(children: [Text("aaa"), Text("bbb")]),
        )
      ],
    );
  }

  void _handleTap() {
    setState(() {
      _wasOpen = !_wasOpen;
    });
    context.read<V2rayPageState>().setSelect(widget.nodeData.index);
  }
}

class RoundedShadow extends StatelessWidget {
  final Widget? child;
  final Color? shadowColor;

  final double topLeftRadius;
  final double topRightRadius;
  final double bottomLeftRadius;
  final double bottomRightRadius;

  const RoundedShadow(
      {Key? key,
      this.shadowColor,
      this.topLeftRadius = 48,
      this.topRightRadius = 48,
      this.bottomLeftRadius = 48,
      this.bottomRightRadius = 48,
      this.child})
      : super(key: key);

  const RoundedShadow.fromRadius(double radius,
      {Key? key, this.child, this.shadowColor})
      : topLeftRadius = radius,
        topRightRadius = radius,
        bottomLeftRadius = radius,
        bottomRightRadius = radius;

  @override
  Widget build(BuildContext context) {
    //Create a border radius, the only applies to the bottom
    var r = BorderRadius.only(
      topLeft: Radius.circular(topLeftRadius),
      topRight: Radius.circular(topRightRadius),
      bottomLeft: Radius.circular(bottomLeftRadius),
      bottomRight: Radius.circular(bottomRightRadius),
    );
    var sColor = shadowColor ?? Color(0x20000000);

    var maxRadius = [
      topLeftRadius,
      topRightRadius,
      bottomLeftRadius,
      bottomRightRadius
    ].reduce(max);
    return Container(
      decoration: new BoxDecoration(
        borderRadius: r,
        boxShadow: [new BoxShadow(color: sColor, blurRadius: maxRadius * .5)],
      ),
      child: ClipRRect(borderRadius: r, child: child),
    );
  }
}
