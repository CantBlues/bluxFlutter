import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'utils/network.dart';

class TaskTypeSetting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Task Types Setting"),
          backgroundColor: Color.fromARGB(255, 53, 28, 8),
          actions: [
            IconButton(
                onPressed: () => showEditType(context, null,null),// here should pass function "getTypes"
                icon: Icon(Icons.add))
          ],
        ),
        body: Container(
            color: Colors.grey[200],
            width: double.infinity,
            child: Center(child: TypesList())));
  }
}

class TypesList extends StatefulWidget {
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
        ? CircularProgressIndicator()
        : ReorderableListView(
            padding: EdgeInsets.only(left: 30, right: 30, top: 30),
            children: _types.map((item) {
              int _id = item["id"];
              String _name = item["name"];
              int _weight = item["weight"];
              return TaskTypeCard(_id, _name, _weight,
                  key: Key(_id.toString()), tap: getTypes);
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
    this.weight, {
    this.tap,
    Key? key,
  }) : super(key: key);
  final String name;
  final int weight;
  final int id;
  final tap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Color.fromARGB(255, Random().nextInt(256),
              Random().nextInt(256), Random().nextInt(256)),
          borderRadius: BorderRadius.all(Radius.circular(15))),
      height: 60,
      margin: EdgeInsets.only(bottom: 30),
      child: Row(children: [
        Container(
            margin: EdgeInsets.only(left: 8),
            child: Center(
                child: Text(weight.toString(),
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 25))),
            width: 30,
            height: double.infinity),
        Expanded(
            child: Container(
          padding: EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                  topRight: Radius.circular(15),
                  bottomRight: Radius.circular(15))),
          child: Row(
            children: [
              Padding(
                  padding: EdgeInsets.only(left: 15),
                  child: Text(name,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20))),
              Expanded(child: Container()),
              IconButton(
                  onPressed: () => showEditType(
                      context, tap, {"id": id, "name": name, "weight": weight}),
                  icon: Icon(Icons.edit)),
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
        return Dialog(child: TypeInfo(info: info ?? null, tap: tap));
      });
}

class TypeInfo extends StatefulWidget {
  const TypeInfo({this.info, this.tap});
  final info;
  final tap;

  @override
  _TypeEditState createState() => _TypeEditState();
}

class _TypeEditState extends State<TypeInfo> {
  final _formKey = GlobalKey<FormState>();

  String _name = "";
  int _weight = 0;
  Map _data = {};

  _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (widget.info != null && widget.info["id"] != null)
        _data["id"] = widget.info["id"];
      _data["name"] = _name;
      _data["weight"] = _weight;
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
        margin: EdgeInsets.all(30),
        child: Form(
            key: _formKey,
            child: FormField(builder: (FormFieldState<Object?> a) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: InputDecoration(labelText: "Name"),
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
                    decoration: InputDecoration(labelText: "Weight"),
                    initialValue: widget.info != null
                        ? widget.info["weight"].toString()
                        : null,
                    keyboardType: TextInputType.number,
                    onSaved: (value) => _weight = int.parse(value!),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          !RegExp(r"^[1-9]\d*$").hasMatch(value)) {
                        return "Please enter number.";
                      }
                      return null;
                    },
                  ),
                  Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: ElevatedButton(
                          onPressed: () => _submit(), child: Text("Submit")))
                ],
              );
            })));
  }
}
