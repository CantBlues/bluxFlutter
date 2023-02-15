import 'package:blux/utils/heapmap.dart';
import 'package:blux/utils/local_auth.dart';
import 'package:blux/utils/network.dart';
import 'package:flutter/material.dart';

class TestPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
        child: Container(
            alignment: Alignment(0, 0),
            margin: EdgeInsets.only(top: 50),
            child: Column(
              children: [
                TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: ((context) => LocalAuthView()))),
                    child: Text("Local Auth")),
                TextButton(
                    onPressed: () => laravel.get("audios/test"),
                    child: Text("laravel")),
                TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: ((context) => Heat()))),
                    child: Text("heatmap")),
                TextButton(
                    onPressed: () => Navigator.of(context).pushNamed("moon"),
                    child: Text("moon"))
              ],
            )));
  }
}
