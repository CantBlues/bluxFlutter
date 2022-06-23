import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:vector_math/vector_math_64.dart' as v;
import 'utils/network.dart';

class VideoList extends StatefulWidget {
  @override
  _VideoListState createState() => _VideoListState();
}

class _VideoListState extends State<VideoList> {
  var _list = <dynamic>[];
  int? count = 0;
  int page = 0;

  void _cardTap(int index) {
    Navigator.of(context).pushNamed('video', arguments: _list[index]);
  }

  void _cardLongPress(int index, BuildContext context) {
    showDialog(
        context: context,
        builder: (context) {
          return ProcessImg(
              md5: _list[index]["Md5"], title: _list[index]["Name"]);
        });
  }

  Widget _buildCard(int index, AsyncSnapshot snap) {
    return Column(
      children: [
        Card(
          child: AspectRatio(
              aspectRatio: 1.5,
              child: Ink.image(
                  child: InkWell(
                      splashColor: Colors.black45,
                      highlightColor: Colors.transparent,
                      onTap: () => _cardTap(index),
                      onLongPress: () => _cardLongPress(index, context)),
                  fit: BoxFit.cover,
                  image: (_list[index]["Images"]
                          ? NetworkImage(mediaHost +
                              "/imgs/${_list[index]["Md5"]}thumb.jpg")
                          : AssetImage("assets/imgPlaceHolder.png"))
                      as ImageProvider<Object>)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          clipBehavior: Clip.antiAlias,
        ),
        Padding(
            child: Text(
              "${_list[index]["Name"]}",
              style: TextStyle(color: Colors.black, fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            padding: EdgeInsets.only(left: 10, right: 10))
      ],
    );
  }

  Future _getVideoList() async {
    Response response;
    response = await Dio().post(host, data: {"page": page + 1});
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
    _getVideoList();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body:
        FutureBuilder(builder: (BuildContext context, AsyncSnapshot snap) {
      return LayoutBuilder(builder: (ctx, cons) {
        int _nums = (cons.maxWidth / 200).round();
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text("Learning Materials"),
              backgroundColor: Colors.pinkAccent,
            ),
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                Response res = await Dio().get(host + '/update');
                if (res.data == '1') {
                  setState(() {
                    page = 0;
                    count = 0;
                    _list = [];
                    _getVideoList();
                  });
                }
                return;
              },
            ),
            SliverGrid(
              delegate:
                  SliverChildBuilderDelegate((BuildContext context, int pos) {
                if (pos >= _list.length - 1 &&
                    _list.length < count! &&
                    this.page != 0) {
                  _getVideoList();
                }
                return _buildCard(pos, snap);
              }, childCount: _list.length),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  childAspectRatio: 1.1, crossAxisCount: _nums),
            )
          ],
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
        );
      });
    }));
  }
}

class CustomRect extends CustomClipper<Rect> {
  CustomRect(this.index, {this.row, this.column, this.ratio});
  int? index, row, column;
  double? ratio;

  @override
  Rect getClip(Size size) {
    Rect r = Rect.fromLTRB(
        column! * (size.width) / 10,
        row! * size.width / ratio! / 10,
        (column! + 1) * (size.width) / 10,
        (row! + 1) * size.width / ratio! / 10);
    return r;
  }

  @override
  bool shouldReclip(CustomRect oldClipper) {
    return true;
  }
}

class ProcessImg extends StatefulWidget {
  ProcessImg({this.md5, this.title});
  final String? md5;
  final String? title;
  @override
  _ProcessImgState createState() => _ProcessImgState();
}

class _ProcessImgState extends State<ProcessImg> {
  int index = 0;
  Image? img;
  double ratio = 1;
  @override
  void initState() {
    super.initState();
    Image img = Image.network(mediaHost + "/imgs/${widget.md5}process.jpg");
    img.image
        .resolve(ImageConfiguration())
        .addListener(ImageStreamListener((ImageInfo info, _) {
      setState(() {
        ratio = info.image.width / info.image.height;
      });
    }));
  }

  @override
  Widget build(context) {
    //double ratio = 16 / 9;
    int row = index ~/ 10;
    int column = index % 10;
    double width = MediaQueryData.fromWindow(window).size.width;
    double height = width / ratio;

    Widget con = Container(
        alignment: Alignment.topLeft,
        transform: Matrix4.compose(v.Vector3(-column * width, -row * height, 0),
            v.Quaternion(0, 0, 0, 0), v.Vector3(10, 10, 1)),
        child: ClipRect(
          clipper: CustomRect(index, row: row, column: column, ratio: ratio),
          child: Image.network(mediaHost + "/imgs/${widget.md5}process.jpg"),
        ));
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        child: Stack(
          children: [
            con,
            Align(
              child: Text(
                widget.title!,
                style: TextStyle(
                    fontSize: 30,
                    color: Colors.black,
                    backgroundColor: Colors.orange),
              ),
              alignment: Alignment(0, 0.3),
            ),
            Slider(
                value: index.toDouble(),
                min: 0,
                max: 99,
                onChanged: (i) {
                  setState(() => index = i.toInt());
                })
          ],
        ),
        onDoubleTap: () => Navigator.of(context).pop(),
      ),
    );
  }
}
