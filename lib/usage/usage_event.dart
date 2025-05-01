import 'package:blux/usage/usage_event_list.dart';
import 'package:flutter/material.dart';

class EventForm extends StatefulWidget {
  const EventForm({super.key});

  @override
  _EventFormState createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  DateTimeRange range = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 1)), end: DateTime.now());
  TimeOfDay time = const TimeOfDay(hour: 0, minute: 0);
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
        appBar: AppBar(title: const Text("Event Options")),
        body: Container(
            margin: const EdgeInsets.all(20),
            alignment: const Alignment(0, 0),
            child: Form(child: FormField(
              builder: (field) {
                DateTime now = DateTime.now();
                DateTime today = DateTime(now.year, now.month, now.day);
                return Column(
                  mainAxisSize: MainAxisSize.min,
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
                                            today.subtract(const Duration(days: 15)),
                                        lastDate: today.add(const Duration(days: 1)),
                                      ) ??
                                      range;
                                  setState(() {});
                                },
                                child: const Text("Select Date"))
                          ],
                        ),
                        const SizedBox(width: 30),
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
                                child: const Text("Select Time"))
                          ],
                        )
                      ],
                    ),
                    TextFormField(
                        decoration: const InputDecoration(label: Text("PackageName")),
                        onChanged: (value) => pkgName = value),
                    const SizedBox(height: 10),
                    const Text("Event Id:"),
                    const SizedBox(height: 10),
                    Expanded(
                        // height: 400,
                        child: GridView.builder(
                            itemCount: 25,
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 80,
                                    crossAxisSpacing: 5,
                                    mainAxisSpacing: 5),
                            itemBuilder: (context, index) {
                              int idx = index + 1;
                              return Row(
                                children: [
                                  Text("$idx"),
                                  Checkbox(
                                      value: eventTypes.contains(idx),
                                      onChanged: (selected) {
                                        selected!
                                            ? eventTypes.add(idx)
                                            : eventTypes.remove(idx);
                                        setState(() {});
                                      })
                                ],
                              );
                            })),
                    Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: ElevatedButton(
                            onPressed: () => submit(), child: const Text("Submit")))
                  ],
                );
              },
            ))));
  }
}
