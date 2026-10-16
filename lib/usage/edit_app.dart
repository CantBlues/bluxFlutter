import 'package:blux/kitt/theme.dart';
import 'package:blux/kitt/widgets.dart';
import 'package:blux/local/local_db.dart';
import 'package:flutter/material.dart';

/// Which tracked apps show up in the usage cockpit — pure local table.
class UsageAppsEditPage extends StatefulWidget {
  const UsageAppsEditPage({super.key});

  @override
  State<UsageAppsEditPage> createState() => _UsageAppsEditPageState();
}

class _UsageAppsEditPageState extends State<UsageAppsEditPage> {
  bool loading = true;
  List apps = [];

  getApps() async {
    final rows = await UsageRepo.apps();
    if (!mounted) return;
    setState(() {
      apps = rows;
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    getApps();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("追踪应用")),
        body: GridBackdrop(
            child: SafeArea(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : apps.isEmpty
                        ? Center(
                            child: Text(
                                "NO APPS TRACKED YET.\nGRANT USAGE ACCESS AND DRIVE A WHILE.",
                                style: KittStyle.body(color: KittColors.textDim)))
                        : ListView.builder(
                            itemCount: apps.length,
                            itemBuilder: ((context, index) {
                              return AppsRow(apps[index], getApps);
                            })))));
  }
}

class AppsRow extends StatelessWidget {
  const AppsRow(this.info, this.tap, {super.key});
  final Map info;
  final Function tap;

  @override
  Widget build(BuildContext context) {
    String packageName = info["pkg"];
    String name = info["name"] ?? "";

    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: KittPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            accent: (info["display"] ?? 1) == 1 ? KittColors.amber : KittColors.textFaint,
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? packageName : name,
                            style: const TextStyle(
                                fontFamily: KittStyle.mono,
                                fontSize: 15,
                                color: KittColors.text)),
                        Text(packageName,
                            style: KittStyle.label(size: 12, color: KittColors.textFaint)),
                      ])),
              IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => showEdit(context)),
              Switch(
                  value: (info["display"] ?? 1) == 1,
                  onChanged: (v) async {
                    await UsageRepo.setDisplay(packageName, v);
                    tap();
                  }),
            ])));
  }

  showEdit(BuildContext c) {
    showDialog(
        context: c,
        builder: (c) => Dialog(
            backgroundColor: KittColors.panel,
            child: AppInfo(info, () {
              Navigator.of(c).pop();
            }, tap)));
  }
}

class AppInfo extends StatefulWidget {
  const AppInfo(this.info, this.close, this.tap, {super.key});
  final Map info;
  final Function close;
  final Function tap;

  @override
  _AppInfoState createState() => _AppInfoState();
}

class _AppInfoState extends State<AppInfo> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();

  _submit() async {
    if (_formKey.currentState!.validate()) {
      await UsageRepo.setName(widget.info["pkg"], _name.text);
      widget.close();
      widget.tap();
    }
  }

  @override
  Widget build(BuildContext context) {
    _name.text = widget.info["name"] ?? "";
    return Container(
        margin: const EdgeInsets.all(30),
        child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.info["pkg"],
                  style: KittStyle.label(size: 12, color: KittColors.textDim)),
              TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: "显示名称"),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? "必填" : null),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: () => widget.close(),
                    child: const Text("取消")),
                const SizedBox(width: 10),
                ElevatedButton(
                    onPressed: _submit, child: const Text("保存")),
              ])
            ])));
  }
}
