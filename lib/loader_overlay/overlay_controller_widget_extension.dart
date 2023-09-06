import 'package:flutter/material.dart';
import 'package:handle_navigation_use_case/loader_overlay/overlay_controller_widget.dart';

///Just a extension to make it cleaner to show or hide the overlay
extension OverlayControllerWidgetExtension on BuildContext {
  OverlayExtensionHelper get loaderOverlay =>
      OverlayExtensionHelper(OverlayControllerWidget.of(this));
}

class OverlayExtensionHelper {
  static final OverlayExtensionHelper _singleton =
      OverlayExtensionHelper._internal();
  late OverlayControllerWidget _overlayController;

  Widget? _widget;
  bool? _visible;

  OverlayControllerWidget get overlayController => _overlayController;

  bool get visible => _visible ?? false;

  factory OverlayExtensionHelper(OverlayControllerWidget? overlayController) {
    if (overlayController != null) {
      _singleton._overlayController = overlayController;
    }

    return _singleton;
  }

  OverlayExtensionHelper._internal();

  Type? get overlayWidgetType => _widget?.runtimeType;

  void show({Widget? widget}) {
    _widget = widget;
    _visible = true;
    _overlayController.setOverlayVisible(_visible!, widget: _widget);
  }

  void hide() {
    _visible = false;
    _overlayController.setOverlayVisible(_visible!);
  }
}
