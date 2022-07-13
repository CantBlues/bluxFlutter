import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/foundation.dart';
import 'eventbus.dart';

bool ipv = false;
String host = "http://192.168.0.174:9999/";
String mediaHost = "http://192.168.0.174:9998/";
BaseOptions options = BaseOptions(
    baseUrl: "http://192.168.0.174:9999/",
    responseType: ResponseType.plain,
    // connectTimeout: 30000,
    receiveTimeout: 30000,
    contentType: Headers.jsonContentType);
Dio dio = Dio(options);

BaseOptions optionsLara = BaseOptions(
    baseUrl: "http://blux.lanbin.com/",
    responseType: ResponseType.plain,
    receiveTimeout: 30000,
    contentType: Headers.jsonContentType);
final dioLara = Dio(optionsLara);
final laravel = LaravelDio();

_parseAndDecode(String response) {
  return jsonDecode(response);
}

class LaravelDio {
  static LaravelDio? _instance;
  late final Dio dio;
  LaravelDio() {
    BaseOptions optionsLara = BaseOptions(
        baseUrl: "http://blux.lanbin.com/api/",
        responseType: ResponseType.json,
        receiveTimeout: 30000,
        contentType: Headers.jsonContentType);
    dio = Dio(optionsLara);
    (dio.transformer as DefaultTransformer).jsonDecodeCallback = parseJson;
    // dio.interceptors.add(InterceptorsWrapper(
    //   onResponse: (e, handler) {
    //     return handler.next(Response(data: "abc",requestOptions:e.requestOptions));
    //   },
    // ));
  }

  parseJson(String text) {
    return compute(_parseAndDecode, text);
  }

  static LaravelDio getInstance() {
    return _instance ??= LaravelDio();
  }
}

const String local = "http://192.168.0.174:9999/";
void listenNetwork() {
  Connectivity()
      .onConnectivityChanged
      .listen((ConnectivityResult result) async {
    if (result == ConnectivityResult.wifi) {
      Response response;
      response = await Dio().get(local + "/checkonline");
      var ret = response.data.toString();
      if (ret == "online") {
        switchIpv(false);
      } else {
        switchIpv(true);
      }
    } else {
      switchIpv(true);
    }
  });
}

void switchIpv(bool ipv6) {
  ipv = ipv6;
  if (ipv6) {
    host = "http://127.0.0.1:19999/";
    mediaHost = "http://127.0.0.1:19998/";
  } else {
    host = "http://192.168.0.174:9999/";
    mediaHost = "http://192.168.0.174:9998/";
  }
  dio = Dio(options.copyWith(baseUrl: host));
  bus.emit("netChange");
}

Future<bool> sendShutDown() async {
  Response response;
  response = await Dio().get(host + "/shutdown");
  var ret = jsonDecode(response.data.toString());
  if (response.statusCode == 200 && ret["Status"]) {
    return true;
  }
  return false;
}

void sendUDP(String ip) {
  RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
      .then((RawDatagramSocket socket) {
    socket.broadcastEnabled = true;
    print('Sending from ${socket.address.address}:${socket.port}');
    int port = 9;
    socket.send(_hexStr2ListInt("FFFFFFFFFFFF" + "D0509914E312" * 16),
        InternetAddress(ip), port);
  });
}

List<int> _hexStr2ListInt(String hex) {
  List<int> ret = [];
  int len = hex.length;
  for (int i = 0; i < len; i = i + 2) {
    int val = _hexToInt(hex.substring(i, i + 2));
    ret.add(val);
  }
  return ret;
}

int _hexToInt(String hex) {
  int val = 0;
  int len = hex.length;
  for (int i = 0; i < len; i++) {
    int hexDigit = hex.codeUnitAt(i);
    if (hexDigit >= 48 && hexDigit <= 57) {
      val += (hexDigit - 48) * (1 << (4 * (len - 1 - i)));
    } else if (hexDigit >= 65 && hexDigit <= 70) {
      // A..F
      val += (hexDigit - 55) * (1 << (4 * (len - 1 - i)));
    } else if (hexDigit >= 97 && hexDigit <= 102) {
      // a..f
      val += (hexDigit - 87) * (1 << (4 * (len - 1 - i)));
    } else {
      throw new FormatException("Invalid hexadecimal value");
    }
  }
  return val;
}

void remoteWake(String ip) async {
  Socket socket = await Socket.connect(ip, 5200);
  print('connected');
  // listen to the received data event stream
  socket.listen((List<int> event) {
    print(event);
  });

  // send hello
  socket.add(<int>[1, 35, 51]);
  await Future.delayed(Duration(seconds: 1));
  socket.add(<int>[5, 35, 51]);

  // wait 5 seconds
  await Future.delayed(Duration(seconds: 5));

  // .. and close the socket
  socket.close();
}

Future<bool> checkOnline() async {
  Response response = await dio.get('checkonline');
  String ret = response.data;
  if (ret == "online") {
    return true;
  }
  return false;
}
