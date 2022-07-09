import 'dart:convert';
import 'package:blux/utils/network.dart';
import 'package:flutter/material.dart';

class UsageAppsEditPage extends StatefulWidget {
  @override
  _UsageAppsEditPageState createState() => _UsageAppsEditPageState();
}

class _UsageAppsEditPageState extends State<UsageAppsEditPage> {
  bool loading = true;
  List apps = [];

  getApps() {
    dioLara.get("/api/phone/apps").then(
      (value) {
        var data = jsonDecode(value.data);
        setState(() {
          apps = data["data"];
          loading = false;
        });
      },
    );
  }

  @override
  void initState() {
    getApps();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        child: Center(
            child: loading
                ? CircularProgressIndicator()
                : Container(
                    child: ListView.builder(
                        itemCount: apps.length,
                        itemBuilder: ((context, index) {
                          return AppsRow(apps[index], getApps);
                        })))));
  }
}

class AppsRow extends StatelessWidget {
  const AppsRow(this.info, this.tap);
  final Map info;
  final tap;

  @override
  Widget build(BuildContext context) {
    String _packageName = info["package_name"];
    String _name = info["name"] ?? "";

    showEdit(Map info) {
      showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: AppInfo(info, tap),
            );
          });
    }

    return Center(
        child: Card(
            margin: EdgeInsets.all(10),
            child: InkWell(
                onTap: () => showEdit(info),
                child: Container(
                  child: Column(
                    children: [
                       Text(_packageName),
                      if(_name != "" ) Text(_name) 
                    ],
                  ),
                  height: 50,width:double.infinity
                ))));
  }
}

class AppInfo extends StatefulWidget {
  const AppInfo(this.info, this.tap);
  final Map info;
  final tap;

  @override
  _AppInfoState createState() => _AppInfoState();
}

class _AppInfoState extends State<AppInfo> {
  final _formKey = GlobalKey<FormState>();

  String _name = "";
  Map _data = {};

  _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (widget.info["id"] != null)
        _data["id"] = widget.info["id"];
        _data["name"] = _name;

      dioLara.post("/api/phone/app/edit", data: _data);
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
                  Text(widget.info["package_name"]),
                  TextFormField(
                    decoration: InputDecoration(labelText: "Name"),
                    initialValue:
                        widget.info["name"],
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
                  Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: ElevatedButton(
                          onPressed: () => _submit(), child: Text("Submit")))
                ],
              );
            })));
  }
}
