import 'package:blux/stars/stars_field.dart';
import 'package:flutter/material.dart';
import 'exchange_channel.dart';
class StarsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ConstellationsListDemo();
  }
}

class ConstellationsListDemo extends StatefulWidget {
  @override
  _ConstellationsListDemoState createState() => _ConstellationsListDemoState();
}

class _ConstellationsListDemoState extends State<ConstellationsListDemo>
    with TickerProviderStateMixin {
  static const double idleSpeed = .2;
  static const double maxSpeed = 10;
  static const int starAnimDurationIn = 4500;

  //double _speed = idleSpeed;
  GlobalKey<NavigatorState> _navigationStackKey = GlobalKey<NavigatorState>();

  ValueNotifier<double> _speedValue = ValueNotifier(idleSpeed);

  late AnimationController _starAnimController;
  late Animation<double> _starAnimSequence;


  @override
  void initState() {
    _starAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: starAnimDurationIn),
      reverseDuration: Duration(milliseconds: starAnimDurationIn ~/ 3),
    );
    _starAnimController.addListener(() {
      _speedValue.value = _starAnimSequence.value;
    });

    //Create an animation sequence that moves our stars back, then forwards, then to rest at 0.
    //This will be played each time we load a detail page, to create a flying through space transition effect
    _starAnimSequence = TweenSequence([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: idleSpeed, end: -2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20.0,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -2, end: 20)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30.0,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 20, end: 0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      )
    ]).animate(_starAnimController);
    super.initState();
  }

  @override
  void dispose() {
    _starAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int starCount = 400;
    //The main content for the app is a Stack, with the StarField as a constant background element, and a Nested Navigator to handle content transitions
    return Scaffold(
      body: Stack(
        children: <Widget>[
          //Wrap stars in a ValueListenableBuilder so it will get rebuilt whenever the _speedValue changes
          ValueListenableBuilder<double>(
            valueListenable: _speedValue,
            builder: (context, value, child) {
              //Scrolling star background
              return StarField(starSpeed: value, starCount: starCount);
            },
          ),
          //Main content
          SafeArea(
            child: NestedNavigator(
              //Need to assign a key to our navigator, so we can pop/push it later
              navKey: _navigationStackKey,
              routeBuilder: _buildPageRoute,
            ),
          ),
        ],
      ),
    );
  }

  //Create a PageRoute to handle the new page transition
  Route _buildPageRoute(RouteSettings route) {
    Widget page;

    page = ConstellationListView(
      onScrolled: _handleListScroll,
      onItemTap: _handleListItemTap,
    );

    //Use a FadeRouteBuilder which fades the new view in, while fading the old page out. Necessary as the content pages have transparent backgrounds.
    return FadeRouteBuilder(page: page);
  }

  //When the list is scrolled, use it's velocity to control the speed of the starfield
  void _handleListScroll(delta) {
    setState(() {
      if (delta == 0) {
        _speedValue.value =
            idleSpeed; //If we've stopped scrolling, revert to the idle speed
      } else {
        _speedValue.value = delta.clamp(
            -maxSpeed, maxSpeed); //clamp scrollDelta to min/max values
      }
    });
  }

  void _handleListItemTap(ConstellationData data, bool redMode) {
    //Add details page to Navigator
    print(data.title);
  }
  //When an item in the list is tapped, push a Detail view onto the navigator. Pass along the data as as route argument.
  // void _handleListItemTap(ConstellationData data, bool redMode) {
  //   //Add details page to Navigator
  //   _navigationStackKey.currentState.pushNamed(
  //     ConstellationDetailView.route,
  //     arguments: _DetailViewRouteArguments(data, redMode),
  //   );
  //   //Start star transition
  //   _starAnimController.forward(from: 0);
  // }

  // void _reverseStarAnim() {
  //   if (_starAnimController.isAnimating) {
  //     _starAnimController.reverse();
  //   } else {
  //     _speedValue.value = idleSpeed;
  //   }
  // }
}

class _DetailViewRouteArguments {
  final ConstellationData data;
  final bool redMode;

  _DetailViewRouteArguments(this.data, this.redMode);
}

class NestedNavigator extends StatefulWidget {
  final Route Function(RouteSettings route) routeBuilder;
  final GlobalKey<NavigatorState> navKey;
  final Function? onBackPop;

  const NestedNavigator(
      {Key? key,
      required this.routeBuilder,
      required this.navKey,
      this.onBackPop})
      : super(key: key);

  @override
  _NestedNavigatorState createState() => _NestedNavigatorState();
}

class _NestedNavigatorState extends State<NestedNavigator> {
  @override
  Widget build(BuildContext context) {
    //Wrap navigator in a WillPop widget, so we can intercept the hardware back button event
    return WillPopScope(
      onWillPop: () async {
        var navigator = widget.navKey.currentState;
        if (navigator!.canPop()) {
          if (widget.onBackPop != null) widget.onBackPop!();
          return true;
        }
        return true;
      },
      child: Navigator(
        key: widget.navKey,
        //Generate a page, in response to a route request
        onGenerateRoute: (routeSettings) => widget.routeBuilder(routeSettings),
        //In order for the nested-navigator to handle hero animations, we must pass it an Observer of type HeroController
        observers: [
          HeroController(
            //Optional: Use a nice arc'd tween instead of the default linear
            createRectTween: (begin, end) =>
                MaterialRectArcTween(begin: begin, end: end),
          )
        ],
      ),
    );
  }
}

class FadeRouteBuilder extends PageRouteBuilder {
  final Widget page;
  final int duration;

  FadeRouteBuilder({required this.page, this.duration = 1000})
      : super(
          transitionDuration: Duration(milliseconds: duration),
          //Page builder doesn't do anything special, just return the page we were passed in.
          pageBuilder: (context, animation, secondaryAnimation) => page,
          //transitionsBuilder builds 2 nested transitions, one for transitionIn (animation), and one for transitionOut (secondaryAnimation)
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
                //Transition from 0 - 1 when coming on the screen
                opacity: Tween<double>(begin: 0, end: 1).animate(animation),
                child: FadeTransition(
                  //Transition from 1 to 0 when leaving the screen
                  opacity: Tween<double>(begin: 1, end: 0)
                      .animate(secondaryAnimation),
                  child: child,
                ));
          },
        );
}
