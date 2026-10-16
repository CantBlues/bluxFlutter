import 'dart:async';
import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets.dart';

/// Knight Industries boot sequence: the scanner wakes, sweeps, and the
/// system reports its modules online before handing over to the cockpit.
class BootPage extends StatefulWidget {
  const BootPage({super.key, this.onDone});
  final VoidCallback? onDone;

  @override
  State<BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<BootPage> with TickerProviderStateMixin {
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
        ..repeat(reverse: true);
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  final List<String> _lines = [];
  static const _boot = [
    "基特工业两千型 · 86 式 瞬变战甲",
    "波斯车辆系统：在线",
    "记忆阵列：一千万亿 比特",
    "本地数据库：已挂载",
    "个人助理协议：就绪",
    "驱动系统 / 生态节能：待机",
    "太阳能收集单元：转换中",
    "涡轮增幅器：待发",
  ];
  Timer? _t;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 380), (timer) {
      if (_i < _boot.length) {
        setState(() => _lines.add(_boot[_i++]));
      } else {
        timer.cancel();
        _fade.forward().then((_) {
          if (mounted) widget.onDone?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _sweep.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("K.I.T.T.",
                        style: KittStyle.glow(size: 42, color: KittColors.red)),
                    const SizedBox(height: 6),
                    Text("KNIGHT RIDER PERSONAL ASSISTANT",
                        style: KittStyle.label(size: 13, color: KittColors.amber)),
                    const SizedBox(height: 40),
                    KittScanner(height: 30, duration: const Duration(milliseconds: 1500)),
                    const SizedBox(height: 34),
                    SizedBox(
                        height: 205,
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _lines
                                .map((l) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text("> $l",
                                        style: KittStyle.label(
                                            size: 13, color: KittColors.textDim, spacing: 1))))
                                .toList())),
                    const SizedBox(height: 20),
                    AnimatedBuilder(
                        animation: _sweep,
                        builder: (_, __) => LinearProgressIndicator(
                            value: _sweep.value,
                            minHeight: 2,
                            backgroundColor: KittColors.redDeep,
                            color: KittColors.red)),
                  ],
                ))));
  }
}
