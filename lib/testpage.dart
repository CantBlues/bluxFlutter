import 'package:blux/utils/heapmap.dart';
import 'package:blux/utils/local_auth.dart';
import 'package:blux/utils/network.dart';
import 'package:flutter/material.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
        child: Container(
            alignment: const Alignment(0, 0),
            margin: const EdgeInsets.only(top: 50),
            child: Column(
              children: [
                TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: ((context) => LocalAuthView()))),
                    child: const Text("Local Auth")),
                TextButton(
                    onPressed: () => laravel.get("audios/test"),
                    child: const Text("laravel")),
                TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: ((context) => Heat()))),
                    child: const Text("heatmap")),
                TextButton(
                    onPressed: () => Navigator.of(context).pushNamed("moon"),
                    child: const Text("moon"))
              ],
            )));
  }
}
