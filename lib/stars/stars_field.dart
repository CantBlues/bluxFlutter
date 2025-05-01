import 'dart:math';
import 'package:blux/home.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'exchange_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'star_field_painter.dart';
import 'package:provider/provider.dart';

class StarField extends StatefulWidget {
  final double starSpeed;
  final int starCount;

  const StarField({super.key, this.starSpeed = 3, this.starCount = 500});

  @override
  _StarFieldState createState() => _StarFieldState();
}

class _StarFieldState extends State<StarField> {
  final List<Star> _stars = [];
  final double _maxZ = 500;
  final double _minZ = 1;
  bool loading = true;

  late Ticker _ticker;

  @override
  void initState() {
    _initStars(context);
    super.initState();
  }

  void _initStars(BuildContext context) {
    //Create stars, randomize their starting values

    for (var i = widget.starCount; i-- > 0;) {
      var s = _randomizeStar(Star(), true);
      _stars.add(s);
    }
    _ticker = Ticker(_handleStarTick)..start();
    setState(() {
      loading = false;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? Container()
        : Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: CustomPaint(
              painter: StarFieldPainter(_stars),
            ),
          );
  }

  void _handleStarTick(Duration elapsed) {
    setState(() {
      advanceStars(widget.starSpeed);
    });
  }

  void advanceStars(double distance) {
    for (var s in _stars) {
      //Move stars on the z, and reset them when they reach the viewport
      s.z -= distance; // * elapsed.inMilliseconds;
      if (s.z < _minZ) {
        _randomizeStar(s, false);
      } else if (s.z > _maxZ) {
        s.z = _minZ;
      }
    }
  }

  Star _randomizeStar(Star star, bool randomZ) {
    Random rand = Random();
    star.x = (-1 + rand.nextDouble() * 2) * 75;
    star.y = (-1 + rand.nextDouble() * 2) * 75;
    star.z = randomZ ? rand.nextDouble() * _maxZ : _maxZ;
    star.rotation = rand.nextDouble() * pi * 2;
    //Some fraction of stars are purple, and bigger than the rest
    if (rand.nextDouble() < .1) {
      star.color = const Color(0xffD4A1FF);
      star.size = 2 + rand.nextDouble() * 2;
    } else {
      star.color = Colors.white;
      star.size = .5 + rand.nextDouble() * 2;
    }
    return star;
  }

  // Future _loadGlowImage() async {
  //   final ByteData data = await rootBundle.load('assets/glow.png');
  //   ui.decodeImageFromList(
  //       new Uint8List.view(data.buffer), (img) => _glowImage = img);
  // }
}

class WsProvider with ChangeNotifier {
  late WebSocketChannel channel;
  List<ConstellationData> data = [
    ConstellationData("WebSocket Initalization", true, "")
  ];
  write(msg, remote, type) {
    data.add(ConstellationData(msg, remote, type));
    notifyListeners();
  }
}

class ConstellationListView extends StatefulWidget {
  static const route = "ConstellationListView";

  final void Function(double) onScrolled;
  final void Function(ConstellationData, bool)? onItemTap;

  const ConstellationListView({
    super.key,
    required this.onScrolled,
    this.onItemTap,
  });

  @override
  _ConstellationListViewState createState() => _ConstellationListViewState();
}

class _ConstellationListViewState extends State<ConstellationListView> {
  double _prevScrollPos = 0;
  double _scrollVel = 0;
  double _uploadProgress = 0;
  bool _uploadProgressShow = false;

  receiveProgress(value) {
    if (value != 1) {
      if (!_uploadProgressShow) _uploadProgressShow = true;
      _uploadProgress = value;
    } else {
      _uploadProgressShow = false;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    //Build list using data
    return Align(
      child: ChangeNotifierProvider<WsProvider>(
        create: (_) => WsProvider(),
        child: SizedBox(
          width: 600,
          child: Stack(
            children: [
              //Scrolling list, draw this first so it's under the other content
              _buildScrollingList(),
              //Cover the list with black gradients on top & bottom
              _buildGradientOverlay(),
              //Top left text
              _buildHeaderText(),
              //Top right text
              _buildLocationText(),
              MessageChannel(receiveProgress),
              _uploadProgressShow
                  ? Center(
                      child: CircularProgressIndicator(value: _uploadProgress))
                  : Container()
            ],
          ),
        ),
      ),
    );
  }

  Container _buildScrollingList() {
    return Container(
      //Wrap list in a NotificationListener, so we can detect scroll updates
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: MessageList(),
      ),
    );
  }

  Widget _buildHeaderText() {
    var provider = context.watch<LockProvider>();
    return Positioned(
      width: 180,
      left: 16,
      top: 16,
      child: GestureDetector(
        onDoubleTap: () => provider.toggle(),
        child: Text(
          "Exchange Channel",
          style: TextStyle(
            color: provider.lock ? Colors.white : Colors.red,
            fontSize: 28,
            height: 1.05,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    double firstGradientStop = .2;
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: const [Colors.black, Color(0x00000000), Color(0x00000000), Colors.black],
                stops: [0, firstGradientStop, 1 - firstGradientStop, 1],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter)),
      ),
    );
  }

  Positioned _buildLocationText() {
    return const Positioned(
      width: 120,
      right: 16,
      top: 12,
      child: Text(
        "New York City (USA, NY) 40.71 °N - 74.01 °W",
        textAlign: TextAlign.right,
        style: TextStyle(
          color: Colors.grey,
          fontSize: 10,
          height: 1.8,
        ),
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    //Determine scrollVelocity and dispatch it to any listeners
    _scrollVel = notification.metrics.pixels - _prevScrollPos;

    widget.onScrolled(_scrollVel);

    //print(notification.metrics.pixels - _prevScroll);
    _prevScrollPos = notification.metrics.pixels;
    //Return true to cancel the notification bubbling, we've handled it here.
    return true;
  }
}
