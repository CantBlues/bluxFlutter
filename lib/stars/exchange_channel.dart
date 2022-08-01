import 'dart:convert';
import 'dart:io';
import 'package:blux/stars/stars_field.dart';
import 'package:blux/utils/network.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

class ConstellationData {
  final String title;
  final bool remote;
  final String type;
  final UniqueKey key = UniqueKey();

  ConstellationData(this.title, this.remote, this.type);
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
          if (widget.data.type == "image")
            Navigator.of(context).push(MaterialPageRoute(
                builder: ((context) =>
                    RemoteImage("http://" + widget.data.title))));
        },
        child: Container(
            padding: EdgeInsets.only(bottom: 32),
            alignment:
                widget.remote ? Alignment.centerLeft : Alignment.centerRight,
            child: Text(
              widget.data.title,
              style:
                  TextStyle(color: widget.remote ? Colors.white : Colors.red),
            )));
  }
}

class MessageChannel extends StatefulWidget {
  MessageChannel({Key? key}) : super(key: key);

  @override
  State<MessageChannel> createState() => _MessageChannelState();
}

class _MessageChannelState extends State<MessageChannel> {
  final ImagePicker imgPicker = ImagePicker();

  void sendMsg(WsProvider value, String type, String msg) {
    value.write(msg, false, type);
    Map _msg = {"type": type, "uid": "flutter", "msg": msg};
    value.channel.sink.add(jsonEncode(_msg));
  }

  uploadCallBack(value) {
    var _provider = context.read<WsProvider>();
    sendMsg(_provider, "image", value.data["data"]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WsProvider>(builder: (context, value, _) {
      return Align(
          alignment: Alignment(0, 0.8),
          child: TextButton(
            child: Image.asset("assets/rocket.png", width: 50),
            onLongPress: () async {
              List<XFile>? imgs = await imgPicker.pickMultiImage();
              if (imgs == null) return;
              for (var img in imgs) {
                var file =
                    await MultipartFile.fromFile(img.path, filename: img.name);
                var _payload = FormData.fromMap({
                  'name': img.name,
                  'file': file,
                });
                laravel
                    .post("file/upload", data: _payload)
                    .then((value) => uploadCallBack(value));
              }
            },
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
                          onSubmitted: (a) {
                            if (_controller.text != "") {
                              sendMsg(value, "msg", _controller.text);
                              Navigator.of(context).pop();
                            }
                          },
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
                                    sendMsg(value, "msg", _controller.text);
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
    channel.stream.listen((data) {
      var message = jsonDecode(data);
      context.read<WsProvider>().write(message["msg"], true, message["type"]);
    });
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

class RemoteImage extends StatelessWidget {
  const RemoteImage(this.src, {Key? key}) : super(key: key);
  final String src;
  @override
  Widget build(BuildContext context) {
    return Material(
        child: Container(
      child: Column(
        children: [
          Image.network(src),
          TextButton(
              onPressed: () async {
                Directory appDocDir = await getApplicationDocumentsDirectory();
                String appDocPath = appDocDir.path;
                String _name =
                    appDocPath + "/" + src.substring(src.length - 30);
                Dio().download(src, _name);
                await ImageGallerySaver.saveFile(_name);
                BotToast.showText(text: "Save Success!");
              },
              child: Text("download"))
        ],
      ),
    ));
  }
}
