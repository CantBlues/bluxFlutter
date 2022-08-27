import 'package:blux/usage/usage_event_list.dart';
import 'package:flutter/material.dart';

class EventForm extends StatefulWidget {
  @override
  _EventFormState createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  DateTimeRange range = DateTimeRange(
      start: DateTime.now().subtract(Duration(days: 1)), end: DateTime.now());
  TimeOfDay time = TimeOfDay(hour: 0, minute: 0);
  String pkgName = "";
  List<int> eventTypes = [];

  submit() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: ((context) =>
            UsageEventView(range, time, pkgName, eventTypes))));
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Event Options")),
        body: Container(
            margin: EdgeInsets.all(20),
            alignment: Alignment(0, 0),
            child: Form(child: FormField(
              builder: (field) {
                DateTime _now = DateTime.now();
                DateTime _today = DateTime(_now.year, _now.month, _now.day);
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text(
                                "${range.start.month}/${range.start.day} - ${range.end.month}/${range.end.day}"),
                            ElevatedButton(
                                onPressed: () async {
                                  range = await showDateRangePicker(
                                        context: context,
                                        firstDate:
                                            _today.subtract(Duration(days: 15)),
                                        lastDate: _today.add(Duration(days: 1)),
                                      ) ??
                                      range;
                                  setState(() {});
                                },
                                child: Text("Select Date"))
                          ],
                        ),
                        SizedBox(width: 30),
                        Column(
                          children: [
                            Text("$time"),
                            ElevatedButton(
                                onPressed: () async {
                                  time = await showTimePicker(
                                          context: context,
                                          initialTime: time) ??
                                      time;
                                  setState(() {});
                                },
                                child: Text("Select Time"))
                          ],
                        )
                      ],
                    ),
                    TextFormField(
                        decoration: InputDecoration(label: Text("PackageName")),
                        onChanged: (_value) => pkgName = _value),
                    SizedBox(height: 10),
                    Text("Event Id:"),
                    SizedBox(height: 10),
                    Expanded(
                        // height: 400,
                        child: GridView.builder(
                            itemCount: 25,
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 80,
                                    crossAxisSpacing: 5,
                                    mainAxisSpacing: 5),
                            itemBuilder: (context, idx) {
                              int _idx = idx + 1;
                              return Row(
                                children: [
                                  Text("$_idx"),
                                  Checkbox(
                                      value: eventTypes.contains(_idx),
                                      onChanged: (selected) {
                                        selected!
                                            ? eventTypes.add(_idx)
                                            : eventTypes.remove(_idx);
                                        setState(() {});
                                      })
                                ],
                              );
                            })),
                    Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: ElevatedButton(
                            onPressed: () => submit(), child: Text("Submit")))
                  ],
                  mainAxisSize: MainAxisSize.min,
                );
              },
            ))));
  }
}
