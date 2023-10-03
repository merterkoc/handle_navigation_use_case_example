// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/back_button_interceptor
import 'dart:async';
import 'dart:core';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// When you need to intercept the Android back-button, you usually add `WillPopScope` to your
/// widget tree. However, under some use cases, specially when developing stateful widgets that
/// interact with the back button, it's more convenient to use the `BackButtonInterceptor`.
///
/// For more info, see: https://pub.dartlang.org/packages/back_button_interceptor
abstract class BackButtonInterceptor implements WidgetsBinding {
  static final List<_FunctionWithZIndex> _interceptors = [];
  static final InterceptorResults results = InterceptorResults();

  static Function(Object, StackTrace) errorProcessing = _errorProcessing;

  static void _errorProcessing(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      print("The BackButtonInterceptor threw an ERROR: $error.");
    }
    Future.delayed(
        const Duration(), () => Error.throwWithStackTrace(error, stackTrace));
  }

  static Future<void> Function() handlePopRouteFunction =
      WidgetsBinding.instance.handlePopRoute;

  static Future<void> Function(String?) handlePushRouteFunction =
      WidgetsBinding.instance.handlePushRoute as Future<void> Function(String?);

  static Future<void> Function(Map<dynamic, dynamic>)
      handlePushRouteInformationFunction =
      WidgetsBinding.instance.handlePushRouteInformation as Future<void>
          Function(Map<dynamic, dynamic>);

  static Future<dynamic> Function(
      MethodCall
          methodCall) handleNavigationInvocationFunction = WidgetsBinding
      .instance.handleNavigationInvocation as Future<dynamic>Function(MethodCall methodCall); // << I added this method here to show an example. Actually dispose should be instant
  // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  // This method is called by the Flutter engine when the user presses the back button(etc).
  // I think can be  public and does not break Flutter's route mechanism. Otherwise I think
  // it may cause more problems if we use it this way.
  // It should be public [WidgetsBinding.instance.handleNavigationInvocation].

  static void add(
    InterceptorFunction interceptorFunction, {
    bool ifNotYetIntercepted = false,
    int? zIndex,
    String? name,
    BuildContext? context,
  }) {
    _interceptors.insert(
        0,
        _FunctionWithZIndex(
          interceptorFunction,
          ifNotYetIntercepted,
          zIndex,
          name,
          (context == null) ? null : getCurrentNavigatorRoute(context),
        ));
    // stableSort(_interceptors);
    /// Here I am replacing the default navigation invocation method with the method I implemented myself.
    SystemChannels.navigation.setMethodCallHandler(_myCustomHandleNavigationInvocation);
  }

  static void remove(InterceptorFunction interceptorFunction) {
    /// Here I need to replace back to the default navigation invocation.
    /// I can't because the method is private.
    /// I can change the default navigation invocation mechanism using SystemChannels.navigation.setMethodCallHandler method.
    /// Therefore, having the WidgetsBinding.instance.handleNavigationInvocation method private does not help anyone.
    /// Making this method public will make the route process more flexible and will not create a vulnerability in the flutter library.
    SystemChannels.navigation.setMethodCallHandler(handleNavigationInvocationFunction);
    _interceptors.removeWhere((interceptor) =>
        interceptor.interceptionFunction == interceptorFunction);
  }

  static void removeByName(String name) {
    _interceptors.removeWhere((interceptor) => interceptor.name == name);
  }

  static void removeAll() {
    _interceptors.clear();
  }

  /// Trick explained here: https://github.com/flutter/flutter/issues/20451
  /// Note `ModalRoute.of(context).settings.name` doesn't always work.
  static Route? getCurrentNavigatorRoute(BuildContext context) {
    Route? currentRoute;
    Navigator.popUntil(context, (route) {
      currentRoute = route;
      return true;
    });
    return currentRoute;
  }

  /// Trick explained here: https://github.com/flutter/flutter/issues/20451
  /// Note `ModalRoute.of(context).settings.name` doesn't always work.
  static String? getCurrentNavigatorRouteName(BuildContext context) =>
      getCurrentNavigatorRoute(context)!.settings.name;

  static Future<dynamic> _myCustomHandleNavigationInvocation(
      MethodCall methodCall) async {
    // POP.
    if (methodCall.method == 'popRoute') {
      return popRoute();
    } else if (methodCall.method == 'pushRoute') {
      return _pushRoute(methodCall.arguments);
    } else if (methodCall.method == 'pushRouteInformation') {
      return _pushRouteInformation(methodCall.arguments);
    } else {
      return Future<dynamic>.value();
    }
  }

  /// All functions are called, in order.
  /// If any function returns true, the combined result is true,
  /// and the default button process will NOT be fired.
  ///
  /// Only if all functions return false (or null), the combined result is false,
  /// and the default button process will be fired.
  ///
  /// Each function gets a boolean that indicates the current combined result
  /// from the previous functions.
  ///
  /// Note: If the interceptor throws an error, a message will be printed to the
  /// console, and a placeholder error will not be thrown. You can change the
  /// treatment of errors by changing the static errorProcessing field.
  static Future popRoute() async {
    bool stopDefaultButtonEvent = false;

    results.clear();

    List<_FunctionWithZIndex> interceptors = List.of(_interceptors);

    for (var i = 0; i < interceptors.length; i++) {
      bool? result;

      try {
        var interceptor = interceptors[i];

        if (!interceptor.ifNotYetIntercepted || !stopDefaultButtonEvent) {
          FutureOr<bool> futureOrBool = interceptor.interceptionFunction(
            stopDefaultButtonEvent,
            RouteInfo(routeWhenAdded: interceptor.routeWhenAdded),
          );

          if (futureOrBool is bool) {
            result = futureOrBool;
          } else {
            throw AssertionError(futureOrBool.runtimeType);
          }
          results.results.add(InterceptorResult(interceptor.name, result));
        }
      } catch (error, stackTrace) {
        errorProcessing(error, stackTrace);
      }

      if (result == true) stopDefaultButtonEvent = true;
    }

    if (stopDefaultButtonEvent) {
      return Future<dynamic>.value();
    } else {
      results.ifDefaultButtonEventWasFired = true;
      return handlePopRouteFunction();
    }
  }

  static Future<void> _pushRoute(dynamic arguments) =>
      handlePushRouteFunction(arguments as String?);

  static Future<void> _pushRouteInformation(dynamic arguments) =>
      // TODO I need to call handlePushRouteInformation function here
      handlePushRouteInformationFunction(arguments as Map<dynamic, dynamic>);

  /// Describes all interceptors, with their names and z-indexes.
  /// This may help you debug your interceptors, by printing them
  /// to the console, like this:
  /// `print(BackButtonInterceptor.describe());`
  static String describe() => _interceptors.join("\n");
}

typedef InterceptorFunction = FutureOr<bool> Function(
  bool stopDefaultButtonEvent,
  RouteInfo routeInfo,
);

/// Your functions can also process information about routes by using the function's RouteInfo info
/// parameter. To get the current route in the navigator, call `info.currentRoute(context)`.
/// Also, `info.routeWhenAdded` contains the route that was the current one when the interceptor
/// was added through the `BackButtonInterceptor.add()` method.
class RouteInfo {
  //

  /// The current route when the interceptor was added
  /// through the BackButtonInterceptor.add() method.
  final Route? routeWhenAdded;

  RouteInfo({this.routeWhenAdded});

  Route? currentRoute(BuildContext context) =>
      BackButtonInterceptor.getCurrentNavigatorRoute(context);

  /// Return true if the current route is NOT the same route of when the interceptor was created.
  ///
  /// This is useful if you want to create an interceptor that only runs when the current route is
  /// the same route of when the interceptor was created:
  /// ```
  /// bool myInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
  ///    if (info.ifRouteChanged(context)) return false;
  ///    ...
  ///  }
  /// ```
  ///
  /// This method can only be called if the [context] parameter was
  /// passed to the [BackButtonInterceptor.add] method.
  ///
  bool ifRouteChanged(BuildContext context) {
    if (routeWhenAdded == null) {
      throw AssertionError("The ifRouteChanged() method "
          "can only be called if the context parameter was "
          "passed to the BackButtonInterceptor.add() method.");
    }

    return !identical(currentRoute(context), routeWhenAdded);
  }
}

class InterceptorResult {
  String? name;
  bool? stopDefaultButtonEvent;

  InterceptorResult(this.name, this.stopDefaultButtonEvent);
}

class InterceptorResults {
  int count = 0;
  List<InterceptorResult> results = [];
  bool ifDefaultButtonEventWasFired = false;

  void clear() {
    results = [];
    ifDefaultButtonEventWasFired = false;
    count++;
  }

  InterceptorResult? getNamed(String name) =>
      results.firstWhereOrNull((result) => result.name == name);
}

class _FunctionWithZIndex implements Comparable<_FunctionWithZIndex> {
  final InterceptorFunction interceptionFunction;
  final bool ifNotYetIntercepted;
  final int? zIndex;
  final String? name;
  final Route? routeWhenAdded;

  _FunctionWithZIndex(
    this.interceptionFunction,
    this.ifNotYetIntercepted,
    this.zIndex,
    this.name,
    this.routeWhenAdded,
  );

  @override
  int compareTo(_FunctionWithZIndex other) {
    if (zIndex == null && other.zIndex == null) {
      return 0;
    } else if (zIndex == null && other.zIndex != null) {
      return 1;
    } else if (zIndex != null && other.zIndex == null) {
      return -1;
    } else {
      return other.zIndex!.compareTo(zIndex!);
    }
  }

  @override
  String toString() =>
      'BackButtonInterceptor: $name, z-index: $zIndex (ifNotYetIntercepted: $ifNotYetIntercepted).';
}
