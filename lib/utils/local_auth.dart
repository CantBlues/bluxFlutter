import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class LocalAuthView extends StatefulWidget {
  const LocalAuthView({super.key});

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
    bool auth0 = await auth.authenticate(localizedReason: "test");
    if(auth0) setState(() => authorized = true);
  }

  @override
  void initState() {
    super.initState();
    auth();
  }

  @override
  Widget build(BuildContext context) {
    return Material(child:authorized
        ? const Center(
            child: Text("authed"),
          )
        : const Icon(Icons.disabled_visible_outlined));
  }
}
