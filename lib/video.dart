import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:video_player/video_player.dart';
import 'utils/network.dart';
import 'package:flutter/services.dart';

class VideoPage extends StatelessWidget {
  const VideoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dynamic args = ModalRoute.of(context)!.settings.arguments;
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: Column(children: [
            Player(url: args["Path"]),
            Expanded(
                child: ListView(
              padding: const EdgeInsets.all(0),
              children: [VideoTitle(args["Name"])],
            ))
          ]),
          backgroundColor: Colors.black,
        ));
  }
}

class Player extends StatefulWidget {
  const Player({super.key, required this.url});
  final String? url;

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  _PlayerState();
  late VideoPlayerController _vpController;
  late ChewieController _controller;
  @override
  initState() {
    super.initState();
    _vpController = VideoPlayerController.network(mediaHost + widget.url!)
      ..initialize().then((_) {
        _controller = ChewieController(
            videoPlayerController: _vpController,
            autoPlay: true,
            aspectRatio: _vpController.value.aspectRatio,
            allowedScreenSleep: false);
        setState(() {});
      });

    //todo
  }

  @override
  build(BuildContext context) {
    return _vpController.value.isInitialized
        ? Padding(
            padding: EdgeInsets.only(
                top: MediaQueryData.fromView(window).padding.top),
            child: AspectRatio(
                aspectRatio: _vpController.value.aspectRatio,
                child: Chewie(controller: _controller)))
        : Container(
            alignment: Alignment.center,
            child: CircularProgressIndicator(),
          );
  }

  @override
  void dispose() {
    super.dispose();
    _vpController.dispose();
    _controller.dispose();
  }
}

class VideoTitle extends StatelessWidget {
  const VideoTitle(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name,
        style: const TextStyle(color: Colors.orangeAccent, fontSize: 30),
      ),
    );
  }
}
