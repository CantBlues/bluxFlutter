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
import 'package:flutter/services.dart';

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
      {super.key, required this.data, this.remote = false, this.onTap});

  @override
  _ConstellationListRendererState createState() =>
      _ConstellationListRendererState();
}

class _ConstellationListRendererState extends State<ConstellationListRenderer> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          if (widget.data.type == "image") {
            Navigator.of(context).push(MaterialPageRoute(
                builder: ((context) =>
                    RemoteImage("http://${widget.data.title}"))));
          } else {
            Clipboard.setData(ClipboardData(text:widget.data.title));
          }
        },
        child: Container(
            padding: const EdgeInsets.only(bottom: 32),
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
  const MessageChannel(this.onProgress, {super.key});
  final onProgress;
  @override
  State<MessageChannel> createState() => _MessageChannelState();
}

class _MessageChannelState extends State<MessageChannel> {
  final ImagePicker imgPicker = ImagePicker();

  void sendMsg(WsProvider value, String type, String msg) {
    value.write(msg, false, type);
    Map msg0 = {"type": type, "uid": "flutter", "msg": msg};
    value.channel.sink.add(jsonEncode(msg0));
  }

  uploadCallBack(value) {
    var provider = context.read<WsProvider>();
    sendMsg(provider, "image", value.data["data"]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WsProvider>(builder: (context, value, _) {
      return Align(
          alignment: const Alignment(0, 0.8),
          child: TextButton(
            child: Image.asset("assets/rocket.png", width: 50),
            onLongPress: () async {
              List<XFile>? imgs = await imgPicker.pickMultiImage();
              for (var img in imgs) {
                var file =
                    await MultipartFile.fromFile(img.path, filename: img.name);
                var payload = FormData.fromMap({
                  'name': img.name,
                  'file': file,
                });
                laravel.post("file/upload", data: payload,
                    onSendProgress: (a, b) {
                  Future.delayed(const Duration(milliseconds: 20));
                  widget.onProgress(a / b);
                }).then((value) => uploadCallBack(value));
              }
            },
            onPressed: () {
              showDialog(
                  context: context,
                  builder: (context) {
                    final controller = TextEditingController();
                    return SimpleDialog(
                      contentPadding: const EdgeInsets.all(10),
                      children: [
                        Center(
                            child: SizedBox(
                          height: 100,
                          child: TextField(
                            maxLines: null,
                            minLines: null,
                            expands: true,
                            autofocus: true,
                            controller: controller,
                            onSubmitted: (a) {
                              if (controller.text != "") {
                                sendMsg(value, "msg", controller.text);
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        )),
                        Center(
                          child: Row(children: [
                            Expanded(
                              child: TextButton(
                                child: const Text("Cancel",
                                    style: TextStyle(color: Colors.red)),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            Expanded(
                              child: TextButton(
                                child: const Text("Confirm", style: TextStyle()),
                                onPressed: () {
                                  if (controller.text != "") {
                                    sendMsg(value, "msg", controller.text);
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
  const MessageList({super.key});

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  late WebSocketChannel channel;
  ScrollController controller = ScrollController();
  late final _wsProvider;

  @override
  void initState() {
    super.initState();
    wsConnect();
    context.read<WsProvider>().addListener(listListener);
  }

  @override
  void didChangeDependencies() {
    _wsProvider = context.read<WsProvider>();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    channel.sink.close();
    _wsProvider.removeListener(listListener);
    controller.dispose();
    super.dispose();
  }

  wsConnect() {
    var provider = context.read<WsProvider>();
    provider.channel = WebSocketChannel.connect(Uri.parse(wsHost));
    channel = provider.channel;
    channel.sink.add('{"type":"login","uid":"flutter","msg":"flutter login"}');
    channel.stream.listen((data) {
      var message = jsonDecode(data);
      provider.write(message["msg"], true, message["type"]);
    }, onDone: () {
      if (!mounted) return; // if page not exist.
      provider.write("Reconnect.", true, "msg");
      wsConnect();
    });
  }

  listListener() {
    controller.jumpTo(controller.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WsProvider>(builder: ((context, value, child) {
      return ListView.builder(
          controller: controller,
          physics: const BouncingScrollPhysics(),
          itemCount: value.data.length,
          //Add some extra padding to the top & bottom of the list
          padding: const EdgeInsets.only(top: 150, bottom: 200, left: 50, right: 50),
          itemBuilder: (context, i) {
            return ConstellationListRenderer(
                data: value.data[i], remote: value.data[i].remote);
          });
    }));
  }
}

class RemoteImage extends StatelessWidget {
  const RemoteImage(this.src, {super.key});
  final String src;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
      color: Colors.black,
      child: Column(
        children: [
          Image.network(src, height: 600, fit: BoxFit.contain),
          TextButton(
              onPressed: () async {
                Directory appDocDir = await getTemporaryDirectory();
                String appDocPath = appDocDir.path;
                String name =
                    "$appDocPath/${src.substring(src.length - 30)}";
                await Dio().download(src, name);
                await ImageGallerySaver.saveFile(name);
                BotToast.showText(text: "Save Success!");
              },
              child: const Text("download"))
        ],
      ),
    ));
  }
}
