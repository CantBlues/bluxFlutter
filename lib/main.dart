import 'package:blux/moon.dart';
import 'package:blux/v2ray/page.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home.dart';
import 'video.dart';
import 'videoList.dart';
import 'audios.dart';
import 'testpage.dart';
import 'usage/usage_page.dart';
import 'usage/edit_app.dart';
import 'taskTypeSetting.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:universal_platform/universal_platform.dart';
import 'usage/usage_utils.dart';
import 'utils/network.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // keep portrait up
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // 加载本地服务器地址
  await loadDomainFromPrefs();
  runApp(MyApp());
  try {
    if (UniversalPlatform.isAndroid && !kDebugMode) {
      FlutterDisplayMode.setHighRefreshRate(); // OnePlus 8 refresh rate lock at 60fps, that show obviously not smooth.
      recordPhoneUsage();
    }
  } catch (e) {
    print(e);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        builder: BotToastInit(),
        title: 'Blux',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        routes: {
          "/": (context) => HomePage(),
          "video": (context) => VideoPage(),
          "videoList": (context) => VideoList(),
          "usage": (context) => UsagePage(),
          "usage_edit_apps": (context) => UsageAppsEditPage(),
          "audios": (context) => AudiosPage(),
          "taskSetting": (context) => TaskTypeSetting(),
          "test": (context) => TestPage(),
          "v2ray": (context) => const V2rayPage(),
          "moon": (context) => const MoonPage(),
        });
  }
}
