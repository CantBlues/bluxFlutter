import 'package:flutter/material.dart';

class ConstellationData {
  final String title;
  final bool remote;
  final String image;

  final UniqueKey key = UniqueKey();

  ConstellationData(this.title, this.remote, this.image);
}

class MessageChannel extends StatefulWidget {
  MessageChannel(this.yell, {Key? key}) : super(key: key);
  final yell;

  @override
  State<MessageChannel> createState() => _MessageChannelState();
}

class _MessageChannelState extends State<MessageChannel> {
  @override
  Widget build(BuildContext context) {
    return Center(

        child: TextButton(
          child: Text("aaa"),
          onPressed: () {
            print("yell");
            widget.yell(ConstellationData("test", false, ''));
          },
        ));
  }
}

class MessageData {
  MessageData(this.yell);
  final yell;
  List<ConstellationData> _constellations = [
    ConstellationData("Aries", true, "Aries"),
    ConstellationData("Cassiopeia", true, "Cassiopeia"),
    ConstellationData("Camelopardalis", true, "Camelopardalis"),
    ConstellationData("Cetus", false, "Cetus"),
    ConstellationData("Pisces", true, "Pisces"),
    ConstellationData("Aries", false, "Aries"),
    ConstellationData("Cassiopeia", false, "Cassiopeia"),
    ConstellationData("Camelopardalis", false, "Camelopardalis"),
    ConstellationData("Aries", true, "Aries"),
    ConstellationData("Cassiopeia", true, "Cassiopeia"),
    ConstellationData("Camelopardalis", true, "Camelopardalis"),
    ConstellationData("Cetus", false, "Cetus"),
    ConstellationData("Pisces", true, "Pisces"),
    ConstellationData("Aries", false, "Aries"),
    ConstellationData("Cassiopeia", false, "Cassiopeia"),
    ConstellationData("Camelopardalis", false, "Camelopardalis"),
    ConstellationData("Aries", true, "Aries"),
    ConstellationData("Cassiopeia", true, "Cassiopeia"),
    ConstellationData("Camelopardalis", true, "Camelopardalis"),
    ConstellationData("Cetus", false, "Cetus"),
    ConstellationData("Pisces", true, "Pisces"),
    ConstellationData("Aries", false, "Aries"),
    ConstellationData("Cassiopeia", false, "Cassiopeia"),
    ConstellationData("Camelopardalis", false, "Camelopardalis"),
  ];

  List<ConstellationData> getConstellations() => _constellations;
}
