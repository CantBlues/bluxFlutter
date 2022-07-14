import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class LocalAuthView extends StatefulWidget {
  @override
  _LocalAuthViewState createState() => _LocalAuthViewState();
}

class _LocalAuthViewState extends State<LocalAuthView> {
  bool authorized = false;
  auth() async {
    final LocalAuthentication auth = LocalAuthentication();
    // final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    // final bool canAuthenticate =
    //     canAuthenticateWithBiometrics || await auth.isDeviceSupported();
    bool _auth = await auth.authenticate(localizedReason: "test");
    if(_auth) setState(() => authorized = true);
  }

  @override
  void initState() {
    super.initState();
    auth();
  }

  @override
  Widget build(BuildContext context) {
    return Material(child:authorized
        ? Center(
            child: Text("authed"),
          )
        : Icon(Icons.disabled_visible_outlined));
  }
}
