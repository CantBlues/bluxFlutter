import 'dart:convert';
import 'package:blux/stars/stars_field.dart';
import 'package:blux/utils/network.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:provider/provider.dart';

class ConstellationData {
  final String title;
  final bool remote;
  final String image;

  final UniqueKey key = UniqueKey();

  ConstellationData(this.title, this.remote, this.image);
}

class ConstellationListRenderer extends StatefulWidget {
  final ConstellationData data;
  final bool remote;
  final Function(ConstellationData, bool)? onTap;

  const ConstellationListRenderer(
      {Key? key, required this.data, this.remote = false, this.onTap})
      : super(key: key);

  @override
  _ConstellationListRendererState createState() =>
      _ConstellationListRendererState();
}

class _ConstellationListRendererState extends State<ConstellationListRenderer> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          if (widget.onTap != null) widget.onTap!(widget.data, false);
        },
        child: Container(
            padding: EdgeInsets.only(bottom: 32),
            alignment:
                widget.remote ? Alignment.centerLeft : Alignment.centerRight,
            child: Text(
              widget.data.title,
              style: TextStyle(color: Colors.white),
            )));
  }
}

class MessageChannel extends StatefulWidget {
  MessageChannel({Key? key}) : super(key: key);

  @override
  State<MessageChannel> createState() => _MessageChannelState();
}

class _MessageChannelState extends State<MessageChannel> {
  @override
  Widget build(BuildContext context) {
    return Consumer<WsProvider>(builder: (context, value, _) {
      return Align(
          alignment: Alignment(0, 0.8),
          child: TextButton(
            child: Image.asset("assets/rocket.png", width: 50),
            onPressed: () {
              showDialog(
                  context: context,
                  builder: (context) {
                    final _controller = TextEditingController();
                    return SimpleDialog(
                      contentPadding: EdgeInsets.all(10),
                      children: [
                        Center(
                            child: TextField(
                          maxLines: 3,
                          autofocus: true,
                          controller: _controller,
                        )),
                        Center(
                          child: Row(children: [
                            Expanded(
                              child: TextButton(
                                child: Text("Cancel",
                                    style: TextStyle(color: Colors.red)),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            Expanded(
                              child: TextButton(
                                child: Text("Confirm", style: TextStyle()),
                                onPressed: () {
                                  if (_controller.text != "") {
                                    sendMsg(value, _controller.text);
                                    Navigator.of(context).pop();
                                  }
                                },
                              ),
                            )
                          ]),
                        )
                      ],
                    );
                  });
            },
          ));
    });
  }

  void sendMsg(WsProvider value, String msg) {
    value.write(msg, false);
    Map _msg = {"type": "msg", "uid": "flutter", "msg": msg};
    value.channel.sink.add(jsonEncode(_msg));
  }
}

class MessageList extends StatefulWidget {
  MessageList({Key? key}) : super(key: key);

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  late WebSocketChannel channel;

  @override
  void initState() {
    super.initState();

    context.read<WsProvider>().channel =
        WebSocketChannel.connect(Uri.parse(wsHost));
    channel = context.read<WsProvider>().channel;
    channel.sink.add('{"type":"login","uid":"flutter","msg":"flutter login"}');
    channel.stream
        .listen((data) => context.read<WsProvider>().write(data, true));
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WsProvider>(builder: ((context, value, child) {
      return ListView.builder(
          physics: BouncingScrollPhysics(),
          itemCount: value.data.length,
          //Add some extra padding to the top & bottom of the list
          padding: EdgeInsets.only(top: 150, bottom: 200, left: 50, right: 50),
          itemBuilder: (context, i) {
            return ConstellationListRenderer(
                data: value.data[i], remote: value.data[i].remote);
          });
    }));
  }
}
