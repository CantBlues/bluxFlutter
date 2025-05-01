import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'utils/network.dart';

class TaskTypeSetting extends StatelessWidget {
  const TaskTypeSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Task Types Setting"),
          backgroundColor: const Color.fromARGB(255, 53, 28, 8),
          actions: [
            IconButton(
                onPressed: () => showEditType(context, null,
                    null), // here should pass function "getTypes"
                icon: const Icon(Icons.add))
          ],
        ),
        body: Container(
            color: Colors.grey[200],
            width: double.infinity,
            child: Center(child: TypesList())));
  }
}

class TypesList extends StatefulWidget {
  const TypesList({super.key});

  @override
  _TypesListState createState() => _TypesListState();
}

class _TypesListState extends State<TypesList> {
  List _types = [];
  bool _loading = true;

  postOrder() {
    for (var i = 0; i < _types.length; i++) {
      _types[i]["sort"] = i + 1;
    }
    dioLara.post("/api/task/types/order", data: _types);
  }

  getTypes() {
    dioLara.get("/api/tasktypes").then((response) {
      var data = jsonDecode(response.data);
      if (data["status"] == "success") {
        setState(() {
          _types = data["data"];
          _loading = false;
        });
      }
    });
  }

  @override
  void initState() {
    getTypes();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const CircularProgressIndicator()
        : ReorderableListView(
            padding: const EdgeInsets.only(left: 30, right: 30, top: 30),
            children: _types.map((item) {
              int id = item["id"];
              String name = item["name"];
              int weight = item["weight"];
              String classify = item["classify"] ?? "";
              return TaskTypeCard(id, name, weight, classify,
                  key: Key(id.toString()), tap: getTypes);
            }).toList(),
            onReorder: (int oldIndex, int newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final dynamic item = _types.removeAt(oldIndex);
                _types.insert(newIndex, item);
              });
              postOrder();
            },
          );
  }
}

class TaskTypeCard extends StatelessWidget {
  const TaskTypeCard(
    this.id,
    this.name,
    this.weight,
    this.classify, {
    this.tap,
    super.key,
  });
  final String name;
  final int weight;
  final int id;
  final String classify;
  final tap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Color.fromARGB(255, Random().nextInt(256),
              Random().nextInt(256), Random().nextInt(256)),
          borderRadius: const BorderRadius.all(Radius.circular(15))),
      height: 60,
      margin: const EdgeInsets.only(bottom: 30),
      child: Row(children: [
        Container(
            margin: const EdgeInsets.only(left: 8),
            width: 30,
            height: double.infinity,
            child: Center(
                child: Text(weight.toString(),
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 25)))),
        Expanded(
            child: Container(
          padding: const EdgeInsets.only(right: 20),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                  topRight: Radius.circular(15),
                  bottomRight: Radius.circular(15))),
          child: Row(
            children: [
              Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20))),
              Expanded(child: Container()),
              IconButton(
                  onPressed: () => showEditType(context, tap, {
                        "id": id,
                        "name": name,
                        "weight": weight,
                        "classify": classify
                      }),
                  icon: const Icon(Icons.edit)),
            ],
          ),
        ))
      ]),
    );
  }
}

showEditType(BuildContext c, tap, info) {
  showDialog(
      context: c,
      builder: (c) {
        return Dialog(child: TypeInfo(info: info, tap: tap));
      });
}

class TypeInfo extends StatefulWidget {
  const TypeInfo({super.key, this.info, this.tap});
  final info;
  final tap;

  @override
  _TypeEditState createState() => _TypeEditState();
}

class _TypeEditState extends State<TypeInfo> {
  final _formKey = GlobalKey<FormState>();

  String _name = "";
  int _weight = 0;
  String _classify = "";
  final Map _data = {};

  _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (widget.info != null && widget.info["id"] != null) {
        _data["id"] = widget.info["id"];
      }
      _data["name"] = _name;
      _data["weight"] = _weight;
      _data["classify"] = _classify;
      dioLara.post("/api/task/type/addoredit", data: _data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving Data')),
      );
      Navigator.of(context).pop();
      widget.tap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.all(30),
        child: Form(
            key: _formKey,
            child: FormField(builder: (FormFieldState<Object?> a) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Name"),
                    initialValue:
                        widget.info != null ? widget.info["name"] : null,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter name.";
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _name = value!;
                    },
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Weight"),
                    initialValue: widget.info != null
                        ? widget.info["weight"].toString()
                        : null,
                    keyboardType: TextInputType.number,
                    onSaved: (value) => _weight = int.parse(value!),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          !RegExp(r"^[0-9]\d*$").hasMatch(value)) {
                        return "Please enter number.";
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "classify"),
                    initialValue:
                        widget.info != null ? widget.info["classify"] : null,
                    onSaved: (value) => _classify = value!,
                  ),
                  Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: ElevatedButton(
                          onPressed: () => _submit(), child: const Text("Submit")))
                ],
              );
            })));
  }
}
