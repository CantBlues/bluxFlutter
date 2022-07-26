import 'dart:math';
import 'stars.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'star_field_painter.dart';

class StarField extends StatefulWidget {
  final double starSpeed;
  final int starCount;

  const StarField({Key? key, this.starSpeed = 3, this.starCount = 500})
      : super(key: key);

  @override
  _StarFieldState createState() => _StarFieldState();
}

class _StarFieldState extends State<StarField> {
  List<Star> _stars = [];
  double _maxZ = 500;
  double _minZ = 1;
  // late ui.Image _glowImage;
  bool loading = true;

  late Ticker _ticker;

  @override
  void initState() {
    // _loadGlowImage().then((a) => _initStars(context));
    _initStars(context);
    super.initState();
  }

  void _initStars(BuildContext context) {
    //Start async image load

    //Create stars, randomize their starting values

    for (var i = widget.starCount; i-- > 0;) {
      var s = _randomizeStar(Star(), true);
      _stars.add(s);
    }
    _ticker = new Ticker(_handleStarTick)..start();
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
              painter: StarFieldPainter(
                _stars
              ),
            ),
          );
  }

  void _handleStarTick(Duration elapsed) {
    setState(() {
      advanceStars(widget.starSpeed);
    });
  }

  void advanceStars(double distance) {
    _stars.forEach((s) {
      //Move stars on the z, and reset them when they reach the viewport
      s.z -= distance; // * elapsed.inMilliseconds;
      if (s.z < _minZ) {
        _randomizeStar(s, false);
      } else if (s.z > _maxZ) {
        s.z = _minZ;
      }
    });
  }

  Star _randomizeStar(Star star, bool randomZ) {
    Random rand = Random();
    star.x = (-1 + rand.nextDouble() * 2) * 75;
    star.y = (-1 + rand.nextDouble() * 2) * 75;
    star.z = randomZ ? rand.nextDouble() * _maxZ : _maxZ;
    star.rotation = rand.nextDouble() * pi * 2;
    //Some fraction of stars are purple, and bigger than the rest
    if (rand.nextDouble() < .1) {
      star.color = Color(0xffD4A1FF);
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

class ConstellationListView extends StatefulWidget {
  static const route = "ConstellationListView";

  final List<ConstellationData> constellations;
  final void Function(double) onScrolled;
  final void Function(ConstellationData, bool)? onItemTap;

  const ConstellationListView(
      {Key? key,
      required this.onScrolled,
      this.onItemTap,
      required this.constellations})
      : super(key: key);

  @override
  _ConstellationListViewState createState() => _ConstellationListViewState();
}

class _ConstellationListViewState extends State<ConstellationListView> {
  double _prevScrollPos = 0;
  double _scrollVel = 0;

  @override
  Widget build(BuildContext context) {
    //Build list using data
    return Align(
      child: Container(
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
            _buildLocationText()
          ],
        ),
      ),
    );
  }

  Container _buildScrollingList() {
    var data = widget.constellations;
    return Container(
      //Wrap list in a NotificationListener, so we can detect scroll updates
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: ListView.builder(
          physics: BouncingScrollPhysics(),
          itemCount: data.length,
          //Add some extra padding to the top & bottom of the list
          padding: EdgeInsets.only(top: 150, bottom: 200, left: 50, right: 50),
          itemBuilder: (context, index) {
            //Create the list renderer, injecting it with some ConstellationData
            return ConstellationListRenderer(
                //Re-dispatch our tap event to anyone who is listening
                onTap: widget.onItemTap,
                remote: data[index].remote,
                data: data[index]);
          },
        ),
      ),
    );
  }

  Widget _buildHeaderText() {
    return Positioned(
      width: 180,
      left: 16,
      top: 16,
      child: Text(
        "Exchange Channel",
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          height: 1.05,
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
                colors: [Colors.black, Color(0x0), Color(0x0), Colors.black],
                stops: [0, firstGradientStop, 1 - firstGradientStop, 1],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter)),
      ),
    );
  }

  Positioned _buildLocationText() {
    return Positioned(
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
          if(widget.onTap != null ) widget.onTap!(widget.data, false);
        },
        child: Container(
            padding: EdgeInsets.only(bottom: 32),
            alignment:
                widget.remote ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              widget.data.title,
              style: TextStyle(color: Colors.white),
            )));
  }
}
