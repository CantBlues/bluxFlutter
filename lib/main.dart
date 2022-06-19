import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home.dart';
import 'video.dart';
import 'videoList.dart';
import 'audios.dart';
import 'usage.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'utils/network.dart';
import 'package:universal_platform/universal_platform.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(MyApp());
  try {
    if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
      await FlutterDisplayMode.setHighRefreshRate();
      listenNetwork();
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
          "/": (context) => Landscape(),
          "video": (context) => VideoPage(),
          "videoList": (context) => VideoList(),
          "usage": (context) => UsagePage(),
          "audios": (context) => AudiosPage(),
          "annual": (context) => Text("a")
        });
  }
}
