import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'network.dart';
import 'dart:convert';


class AudiosPage extends StatelessWidget {
  AudiosPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("listening practice"),
      ),
      body: AudioList(),
    );
  }
}

class AudioList extends StatefulWidget {
  @override
  _AudioListState createState() => _AudioListState();
}

class _AudioListState extends State<AudioList> {
  var _list = <dynamic>[];
  int? count = 0;
  int page = 0;
  Future _getAudioList() async {
    print(page);
    Response response;
    response = await Dio().post(host + "getaudios", data: {"page": page + 1});
    var ret = jsonDecode(response.data.toString());
    if (response.statusCode == 200 && ret["Status"]) {
      setState(() {
        _list.addAll(ret["Data"]);
        page++;
        count = ret["Count"];
      });
    } else {
      print("network error");
    }
  }

  @override
  void initState() {
    super.initState();
    _getAudioList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (BuildContext context, int index) {
        if (index >= _list.length - 1) {
          _getAudioList();
        }
        return ListTile(
          title: Text(_list[index]["Name"]),
          tileColor: index.isEven ? Colors.white : Colors.pink[100],
          onTap: () => Navigator.of(context).pushNamed('video', arguments: _list[index])
              
        );
      },
      itemCount: _list.length,
    );
  }
}

class AudioPlayer extends StatefulWidget {
  AudioPlayer({Key? key, required this.url}) : super(key: key);
  final String? url;

  @override
  _AudioPlayerState createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<AudioPlayer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(context) {
    return Text('');
  }
}
