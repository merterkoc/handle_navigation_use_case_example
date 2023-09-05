import 'package:flutter/material.dart';
import 'package:handle_navigation_use_case/back_button_interceptor/back_button_interceptor.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _myInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    print("BACK BUTTON PRESSED!"); // Do some stuff.
    return true;
  }

  @override
  void initState() {
    /// When using BackButtonInterceptor, calling the SystemChannels.navigation.setMethodCallHandler(_handleNavigationInvocation).
    BackButtonInterceptor.add(_myInterceptor);
    super.initState();
  }

  @override
  void dispose() {
    /// There is no way to undo the call handler we added when it is disposed.
    BackButtonInterceptor.remove(_myInterceptor);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Home Page')),
      body: const Center(child: Text('Detail Screen')));
}
