import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'package:video_player/video_player.dart';
import 'network.dart';

class VideoPage extends StatelessWidget {
  VideoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dynamic args = ModalRoute.of(context)!.settings.arguments;
    return ListView(
      children: [Player(url: args["Path"])],
      padding:
          EdgeInsets.only(top: MediaQueryData.fromWindow(window).padding.top),
    );
  }
}

class Player extends StatefulWidget {
  Player({Key? key, required this.url}) : super(key: key);
  final String? url;

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  _PlayerState();
  late VideoPlayerController _vpController;
  late ChewieController _controller;
  @override
  Future<void> initState() async {
    super.initState();
    print(mediaHost + widget.url!);
    _vpController = VideoPlayerController.network(mediaHost + widget.url!);
    await Future.wait([_vpController.initialize()]);
    _controller = ChewieController(
        videoPlayerController: _vpController,
        autoPlay: true,
        aspectRatio: _vpController.value.aspectRatio,
        allowedScreenSleep: false);
    setState(() {});
  }

  @override
  build(BuildContext context) {
    return Chewie(controller: _controller);
  }

  @override
  void dispose() {
    super.dispose();
    _vpController.dispose();
    _controller.dispose();
  }
}
