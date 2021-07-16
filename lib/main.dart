import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'home.dart';
import 'video.dart';
import 'videoList.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'dart:io';

void main() async {
  runApp(MyApp());
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      await FlutterDisplayMode.setHighRefreshRate();
    } 
  } catch (e) {
    print(e);
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Blux',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        routes: {
          "/": (context) => MyHomePage(title: 'Blux'),
          "video": (context) => VideoPage(),
          "videoList": (context) => VideoList()
        });
  }
}
