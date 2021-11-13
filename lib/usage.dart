import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'package:dio/dio.dart';
import 'utils/network.dart';
import 'utils/db.dart';

class UsagePage extends StatelessWidget {
  UsagePage({Key? key}) : super(key: key);

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("usage"),
        actions: [
          IconButton(
              onPressed: () {
                deleteDb();
              },
              icon: const Icon(Icons.delete_forever)),
          IconButton(
            icon: Icon(Icons.upgrade),
            onPressed: () async {
              print("upgrade");
              sendUsageToServer();
            },
          )
        ],
      ),
      body: UsageContent(
        title: "usage",
      ),
    );
  }
}

class UsageContent extends StatefulWidget {
  UsageContent({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _UsageContentState createState() => _UsageContentState();
}

class _UsageContentState extends State<UsageContent> {
  Future<List<Map<String, dynamic>>> _getAppUsage(
      DateTime from, DateTime to) async {
    var _db = await dbHelper.open();
    List<Map<String, dynamic>> ret = await _db!.rawQuery('''
      SELECT a.id, a.usage,a.appid,a.node,b.id AS bid, b.name,b.package FROM usage a LEFT JOIN apps b ON bid = a.appid;
    ''');
    return ret;
  }

  @override
  Widget build(BuildContext context) {
    DateTime startDate = DateTime(2021, 10, 18);
    DateTime endDate = new DateTime.now();
    Future<List<Map<String, dynamic>>> infos = _getAppUsage(startDate, endDate);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: infos,
      builder: (BuildContext context,
          AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        return Center(
          child: ListView.builder(
            itemBuilder: (BuildContext context, int index) {
              return Column(
                children: [
                  Text(snapshot.data?[index]["id"].toString() ?? '',
                      style: TextStyle(color: Colors.red)),
                  Text((snapshot.data?[index]).toString())
                ],
              );
            },
            itemCount: snapshot.data?.length,
          ),
        );
      },
    );
  }
}
