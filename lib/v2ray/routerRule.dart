import 'dart:convert';

import 'package:blux/utils/network.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

class RouterRules extends StatefulWidget {
  RouterRules({Key? key}) : super(key: key);

  @override
  State<RouterRules> createState() => _RouterRulesState();
}

class RulesProvider extends ChangeNotifier {
  List _directRules = [];
  List _proxyRules = [];

  set directRules(List rules) {
    _directRules = rules;
    notifyListeners();
  }

  set proxyRules(List rules) {
    _proxyRules = rules;
    notifyListeners();
  }

  List get directRules => _directRules;
  List get proxyRules => _proxyRules;
}

class _RouterRulesState extends State<RouterRules> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: ChangeNotifierProvider(
            create: (context) => RulesProvider(),
            builder: (context, _) {
              return Container(
                  child: Column(
                children: [
                  Expanded(
                      flex: 12,
                      child: FutureBuilder(
                          future: Dio()
                              .get(Openwrt + "routerule/get")
                              .then((value) {
                            var data = jsonDecode(value.data.toString());
                            context.read<RulesProvider>().directRules =
                                data["directDomain"];
                            context.read<RulesProvider>().proxyRules =
                                data["proxyDomain"];
                          }),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting)
                              return Center(child: CircularProgressIndicator());
                            return RulesPanel();
                          })),
                  Expanded(
                    flex: 1,
                    child: Container(
                        color: Colors.blue,
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: () {
                              var _directRules =
                                  context.read<RulesProvider>().directRules;
                              var _proxyRules =
                                  context.read<RulesProvider>().proxyRules;
                              Dio().post(Openwrt + "routerule/set", data: {
                                "proxy": _proxyRules,
                                "direct": _directRules
                              }).then(((value) =>
                                  BotToast.showText(text: "Posted!")));
                            },
                            child: Text(
                              "Confirm",
                              style: TextStyle(fontSize: 26),
                            ))),
                  )
                ],
              ));
            }));
  }
}

class RulesPanel extends StatefulWidget {
  RulesPanel({Key? key}) : super(key: key);

  @override
  State<RulesPanel> createState() => _RulesPanelState();
}

class _RulesPanelState extends State<RulesPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
        child: Row(
      children: [
        Expanded(child: RulesScroll("direct")),
        Expanded(
          child: RulesScroll("proxy"),
        )
      ],
    ));
  }
}

class RulesScroll extends StatefulWidget {
  RulesScroll(this.tag, {Key? key}) : super(key: key);
  final String tag;

  @override
  State<RulesScroll> createState() => _RulesScrollState();
}

class _RulesScrollState extends State<RulesScroll> {
  List data = [];
  @override
  Widget build(BuildContext context) {
    return Consumer<RulesProvider>(
      builder: (context, value, child) {
        bool isDirect = (widget.tag == "direct") ? true : false;
        data = isDirect ? value.directRules : value.proxyRules;
        return Container(
            child: ListView.builder(
          itemCount: data.length + 2,
          itemBuilder: (context, index) {
            if (index == 0)
              return Center(
                  child: Text(widget.tag, style: TextStyle(fontSize: 24)));
            if (index == data.length + 1)
              return Container(
                  padding: EdgeInsets.only(left: 60, right: 60),
                  child: ElevatedButton(
                      child: Icon(Icons.add),
                      onPressed: () {
                        if (isDirect) {
                          data.add("");
                          value.directRules = data;
                        } else {
                          data.add("");
                          value.proxyRules = data;
                        }
                      }));
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () {
                data.removeAt(index - 1);
                if (isDirect)
                  value.directRules = data;
                else
                  value.proxyRules = data;
              },
              child: Container(
                child: TextFormField(
                  initialValue: data[index - 1],
                  onChanged: (v) {
                    data[index - 1] = v;
                    if (isDirect)
                      value.directRules = data;
                    else
                      value.proxyRules = data;
                  },
                ),
                margin: EdgeInsets.all(10),
              ),
            );
          },
        ));
      },
    );
  }
}
