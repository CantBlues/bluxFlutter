import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'package:video_player/video_player.dart';
import 'network.dart';

class VideoPage extends StatelessWidget {
  VideoPage({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dynamic args = ModalRoute.of(context).settings.arguments;
    return Padding(
      child: Column(children: [Player(url: args["Path"])]),
      padding:
          EdgeInsets.only(top: MediaQueryData.fromWindow(window).padding.top),
    );
  }
}

class Player extends StatefulWidget {
  Player({Key key, @required this.url}) : super(key: key);
  final String url;

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  _PlayerState();
  VideoPlayerController _vpController;
  ChewieController _controller;
  @override
  void initState() {
    super.initState();
    _vpController = VideoPlayerController.network(mediaHost + widget.url)
      ..initialize().then((_) {
        setState(() {});
        _controller = ChewieController(
            videoPlayerController: _vpController,
            autoPlay: true,
            aspectRatio: _vpController.value.aspectRatio ?? 1,
            allowedScreenSleep: false);
      });
  }

  @override
  build(BuildContext context) {
    return _vpController.value.initialized
        ? Chewie(controller: _controller)
        : SizedBox();
  }

  @override
  void dispose() {
    super.dispose();
    _vpController.dispose();
    _controller.dispose();
  }
}
