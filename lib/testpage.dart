import 'package:blux/utils/local_auth.dart';
import 'package:flutter/material.dart';

class TestPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
        child: Container(alignment: Alignment(0,0),margin: EdgeInsets.only(top:50),child:Column(
      children: [
        TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: ((context) => LocalAuthView()))),
            child: Text("Local Auth"))
      ],
    )));
  }
}