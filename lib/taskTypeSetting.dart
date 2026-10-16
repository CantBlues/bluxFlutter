import 'package:blux/kitt/theme.dart';
import 'package:blux/kitt/widgets.dart';
import 'package:blux/local/local_db.dart';
import 'package:flutter/material.dart';

class TaskTypeSetting extends StatelessWidget {
  const TaskTypeSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("任务类型设置"),
          actions: [
            IconButton(
                onPressed: () => showEditType(context, null),
                icon: const Icon(Icons.add))
          ],
        ),
        body: const GridBackdrop(child: SafeArea(child: Center(child: TypesList()))));
  }
}

class TypesList extends StatefulWidget {
  const TypesList({super.key});

  @override
  _TypesListState createState() => _TypesListState();
}

class _TypesListState extends State<TypesList> {
  List<TaskType> _types = [];
  bool _loading = true;

  getTypes() async {
    final types = await TaskRepo.types();
    if (!mounted) return;
    setState(() {
      _types = types;
      _loading = false;
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
        ? const Center(child: CircularProgressIndicator())
        : ReorderableListView(
            padding: const EdgeInsets.only(left: 30, right: 30, top: 30),
            children: _types
                .map((t) => TaskTypeCard(t, key: Key(t.id.toString()), tap: getTypes))
                .toList(),
            onReorder: (int oldIndex, int newIndex) async {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _types.removeAt(oldIndex);
                _types.insert(newIndex, item);
              });
              await TaskRepo.saveOrder(_types);
            },
          );
  }
}

class TaskTypeCard extends StatelessWidget {
  const TaskTypeCard(this.type, {this.tap, super.key});
  final TaskType type;
  final Function? tap;

  @override
  Widget build(BuildContext context) {
    final classifyColor = switch (type.classify) {
      'body' => KittColors.red,
      'soul' => KittColors.cyan,
      'steps' => KittColors.amber,
      _ => KittColors.textFaint,
    };
    return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: KittPanel(
            accent: classifyColor,
            child: Row(children: [
              SizedBox(
                  width: 34,
                  child: Text(type.weight.toString(),
                      style: KittStyle.value(size: 22, color: classifyColor))),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(type.name,
                        style: const TextStyle(
                            fontFamily: KittStyle.mono,
                            fontSize: 19,
                            color: KittColors.text,
                            fontWeight: FontWeight.bold)),
                    if (type.classify.isNotEmpty)
                      Text(switch (type.classify) {
                        'body' => "体能",
                        'soul' => "心灵",
                        'steps' => "步数",
                        _ => type.classify,
                      }, style: KittStyle.label(size: 12, color: classifyColor, spacing: 1)),
                  ])),
              IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => showEditType(context, type, tap: tap)),
            ])));
  }
}

showEditType(BuildContext c, TaskType? type, {Function? tap}) {
  showDialog(
      context: c,
      builder: (c) {
        return Dialog(
            backgroundColor: KittColors.panel,
            child: TypeInfo(type: type, tap: tap));
      });
}

class TypeInfo extends StatefulWidget {
  const TypeInfo({super.key, this.type, this.tap});
  final TaskType? type;
  final Function? tap;

  @override
  _TypeEditState createState() => _TypeEditState();
}

class _TypeEditState extends State<TypeInfo> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name =
      TextEditingController(text: widget.type?.name ?? "");
  late final TextEditingController _weight =
      TextEditingController(text: (widget.type?.weight ?? 1).toString());
  late final TextEditingController _classify =
      TextEditingController(text: widget.type?.classify ?? "");

  _submit() async {
    if (_formKey.currentState!.validate()) {
      if (widget.type != null) {
        final t = widget.type!;
        t.name = _name.text;
        t.weight = int.parse(_weight.text);
        t.classify = _classify.text;
        await TaskRepo.editType(t);
      } else {
        await TaskRepo.addType(_name.text,
            weight: int.parse(_weight.text), classify: _classify.text);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.tap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.all(24),
        child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.type == null ? "添加任务类型" : "编辑任务类型",
                  style: KittStyle.glow(size: 15)),
              const SizedBox(height: 18),
              TextFormField(
                  controller: _name,
                  autofocus: widget.type == null,
                  decoration: const InputDecoration(labelText: "名称"),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? "必填" : null),
              TextFormField(
                  controller: _weight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "权重"),
                  validator: (value) => (value == null ||
                          value.isEmpty ||
                          !RegExp(r"^[0-9]\d*$").hasMatch(value))
                      ? "仅数字"
                      : null),
              TextFormField(
                  controller: _classify,
                  decoration: const InputDecoration(
                      labelText: "分类（body / soul / steps）"),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    const allowed = {'body', 'soul', 'steps'};
                    return allowed.contains(value) ? null : "body | soul | steps";
                  }),
              const SizedBox(height: 24),
              Row(children: [
                if (widget.type != null)
                  TextButton(
                      onPressed: () async {
                        await TaskRepo.deleteType(widget.type!.id);
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        widget.tap?.call();
                      },
                      child: const Text("删除",
                          style: TextStyle(color: KittColors.red))),
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("取消")),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _submit, child: const Text("保存")),
              ])
            ])));
  }
}
