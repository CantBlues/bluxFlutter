import 'package:blux/local/ad_notify.dart';
import 'package:blux/local/local_db.dart';
import 'package:blux/moon.dart';
import 'package:blux/v2ray/page.dart';
import 'package:blux/habits.dart';
import 'package:blux/ads.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home.dart';
import 'package:provider/provider.dart';
import 'billboard.dart';
import 'task_layer.dart';
import 'stars/stars.dart';
import 'video.dart';
import 'videoList.dart';
import 'audios.dart';
import 'testpage.dart';
import 'usage/usage_page.dart';
import 'usage/edit_app.dart';
import 'taskTypeSetting.dart';
import 'kitt/splash.dart';
import 'kitt/theme.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:universal_platform/universal_platform.dart';
import 'usage/usage_utils.dart';
import 'utils/network.dart';

/// lets the notification tap jump straight into the ad log page
final navKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // keep portrait up
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // local server address (only needed for the online modules)
  await loadDomainFromPrefs();
  // open local storage + first-run seed
  await LocalDb.instance.db;
  await TaskRepo.ensureSeeded();
  // daily ad-log reminder (stored schedule re-armed on every start)
  await AdNotify.init();
  AdNotify.onOpenAds = () => navKey.currentState?.pushNamed("ads");
  await AdNotify.rescheduleFromPrefs();
  try {
    if (UniversalPlatform.isAndroid && !kDebugMode) {
      FlutterDisplayMode.setHighRefreshRate(); // OnePlus 60fps lock looks rough
      recordPhoneUsage(); // collect to local db, no server required
    }
  } catch (e) {
    print(e);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LockProvider>(
        create: (_) => LockProvider(),
        child: MaterialApp(
        navigatorKey: navKey,
        builder: BotToastInit(),
        title: 'K.I.T.T.',
        theme: kittTheme(),
        initialRoute: "boot",
        routes: {
          "boot": (context) => BootPage(
              onDone: () => Navigator.of(context).pushReplacementNamed("/")),
          "/": (context) => const HomePage(),
          "video": (context) => const VideoPage(),
          "videoList": (context) => const VideoList(),
          "usage": (context) => const UsagePage(),
          "usage_edit_apps": (context) => const UsageAppsEditPage(),
          "audios": (context) => const AudiosPage(),
          "taskSetting": (context) => const TaskTypeSetting(),
          "billboard": (context) => const Billboard(),
          "tasks": (context) => const TaskLayer(),
          "habits": (context) => const HabitsPage(),
          "ads": (context) => const AdsPage(),
          "stars": (context) => const StarsPage(),
          "test": (context) => const TestPage(),
          "v2ray": (context) => const V2rayPage(),
          "moon": (context) => const MoonPage(),
        }));
  }
}
