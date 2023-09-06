import 'package:flutter/material.dart';
import 'package:handle_navigation_use_case/loader_overlay/overlay_controller_widget_extension.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  @override
  void initState() {
    /// When using BackButtonInterceptor, calling the SystemChannels.navigation.setMethodCallHandler(_handleNavigationInvocation).
    // BackButtonInterceptor.add(_myInterceptor);
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(
        const Duration(seconds: 5),
        () => context.loaderOverlay.hide(),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Home Page')),
      body: const Center(child: Text('Detail Screen')));
}
