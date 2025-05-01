import 'package:blux/billboard.dart';
import 'package:blux/utils/network.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'page.dart';

class NodeData {
  final data;
  final int index;
  NodeData({this.data, this.index = 0});
}

class NodeCard extends StatefulWidget {
  const NodeCard(this.nodeData, {super.key});
  final NodeData nodeData;

  @override
  _NodeCardState createState() => _NodeCardState();
}

class _NodeCardState extends State<NodeCard> {
  final double nominalHeightClosed = 80;
  final double nominalHeightOpen = 180;
  bool _wasOpen = false;

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<NodesViewState>().selected;
    if (selected != widget.nodeData.index) _wasOpen = false;
    final wasOpen = _wasOpen && selected == widget.nodeData.index;
    final currentNode = context.watch<NodesViewState>().current;
    bool connected = false;
    if (currentNode != null) {
      connected = widget.nodeData.data['port'].toString() ==
              currentNode["port"].toString() &&
          widget.nodeData.data['add'] == currentNode["add"];
    }
    double cardHeight = wasOpen ? nominalHeightOpen : nominalHeightClosed;

    return GestureDetector(
      onTap: _handleTap,
      //Use an animated container so we can easily animate our widget height
      child: AnimatedContainer(
          curve: !wasOpen ? const ElasticOutCurve(.9) : Curves.elasticOut,
          duration: Duration(milliseconds: !wasOpen ? 800 : 1200),
          height: cardHeight,
          //Wrap content in a rounded shadow widget, so it will be rounded on the corners but also have a drop shadow

          child: BlurCard(
              Container(
                color: connected
                    ? Colors.red.withAlpha(196)
                    : Colors.white.withAlpha(32),
                child: Stack(fit: StackFit.expand, children: <Widget>[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    //Wrap content in a ScrollView, so there's no errors on over scroll.
                    child: SingleChildScrollView(
                      //We don't actually want the scrollview to scroll, disable it.
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          //Top Header Row
                          _buildTopContent(),
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
              bottom: 0,
              left: 20,
              right: 20)),
    );
  }

  Row _buildTopContent() {
    String delayText = (widget.nodeData.data["delay"] == ""
            ? "-"
            : widget.nodeData.data["delay"]) ??
        "-";
    if (delayText.length > 4) delayText = delayText.substring(0, 4);
    delayText += " s";
    String speedText = (widget.nodeData.data["speed"] == ""
            ? "-"
            : widget.nodeData.data["speed"]) ??
        "-";
    if (speedText.length > 4) speedText = speedText.substring(0, 4);
    speedText += " M/s";
    return Row(
      children: <Widget>[
        Expanded(
          flex: 4,
          child: Text(widget.nodeData.data["ps"],
              style: const TextStyle(color: Colors.white)),
        ),
        Expanded(
          flex: 1,
          child: Center(
              child: Column(
            children: [
              Text(
                delayText,
                style: const TextStyle(color: Colors.lightGreen),
              ),
              Text(
                speedText,
                style: const TextStyle(color: Colors.lightGreen),
              ),
              Text(widget.nodeData.data["ping"].toString(),
                  style: const TextStyle(color: Colors.lightGreen))
            ],
          )),
        )
      ],
    );
  }

  Widget _buildMainContent() {
    var data = widget.nodeData.data;
    data["port"] = data["port"].toString();
    return Column(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
                text: TextSpan(children: [
              const TextSpan(text: "addr: ", style: TextStyle(color: Colors.yellow)),
              TextSpan(text: data["add"], style: const TextStyle(color: Colors.white))
            ])),
            RichText(
                text: TextSpan(children: [
              const TextSpan(text: "port: ", style: TextStyle(color: Colors.yellow)),
              TextSpan(
                  text: data["port"], style: const TextStyle(color: Colors.white))
            ])),
            RichText(
                text: TextSpan(children: [
              const TextSpan(
                  text: "protocol: ", style: TextStyle(color: Colors.yellow)),
              TextSpan(
                  text: data["protocol"], style: const TextStyle(color: Colors.white))
            ]))
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: ElevatedButton(
            child: const Text("Go"),
            onPressed: () {
              if (widget.nodeData.data["bid"] != null) {
                widget.nodeData.data["id"] = widget.nodeData.data[
                    "bid"]; //  laravel bug convert uid to id using 'as' keyword
              }
              Dio()
                  .post("${Openwrt}nodes/set", data: widget.nodeData.data)
                  .then(
                    (value) => context.read<NodesViewState>().fetchConfig(),
                  );
            },
          ),
        )
      ],
    );
  }

  void _handleTap() {
    setState(() {
      _wasOpen = !_wasOpen;
    });
    context.read<NodesViewState>().setSelect(widget.nodeData.index);
  }
}
