// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/back_button_interceptor
library back_button_interceptor;

import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class BackButtonInterceptor implements WidgetsBinding {
  static final List<_FunctionWithZIndex> _interceptors = [];
  static final InterceptorResults results = InterceptorResults();

  static Function(Object, StackTrace) errorProcessing = _errorProcessing;

  static void _errorProcessing(Object error, StackTrace stackTrace) {
    print("The BackButtonInterceptor threw an ERROR: $error.");
    Future.delayed(
        const Duration(), () => Error.throwWithStackTrace(error, stackTrace));
  }

  static Future<void> Function() handlePopRouteFunction =
      WidgetsBinding.instance.handlePopRoute;

  static Future<void> Function(String?) handlePushRouteFunction =
      WidgetsBinding.instance.handlePushRoute as Future<void> Function(String?);

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
    stableSort(_interceptors);
    SystemChannels.navigation.setMethodCallHandler(_handleNavigationInvocation);

    SystemChannels.navigation.setMethodCallHandler(WidgetsBinding.instance
        .handleNavigationInvocation); // << I added this method here to show an example. Actually dispose should be instant
    // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    // This method is called by the Flutter engine when the user presses the back button(etc).
    // I think can be  public and does not break Flutter's route mechanism. Otherwise I think
    // it may cause more problems if we use it this way.
    // It should be public [WidgetsBinding.instance.handleNavigationInvocation].
  }

  static void remove(InterceptorFunction interceptorFunction) {
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

  static Future<dynamic> _handleNavigationInvocation(
      MethodCall methodCall) async {
    // POP.
    if (methodCall.method == 'popRoute')
      return popRoute();

    // PUSH.
    else if (methodCall.method == 'pushRoute')
      return _pushRoute(methodCall.arguments);

    // OTHER.
    else
      return Future<dynamic>.value();
  }

  static Future popRoute() async {
    bool stopDefaultButtonEvent = false;

    results.clear();

    List<_FunctionWithZIndex> interceptors = List.of(_interceptors);

    for (var i = 0; i < interceptors.length; i++) {
      bool? result;

      try {
        var interceptor = interceptors[i];

        if (!interceptor.ifNotYetIntercepted || !stopDefaultButtonEvent) {
          FutureOr<bool> _result = interceptor.interceptionFunction(
            stopDefaultButtonEvent,
            RouteInfo(routeWhenAdded: interceptor.routeWhenAdded),
          );

          if (_result is bool)
            result = _result;
          // ignore: unnecessary_type_check
          else if (_result is Future<bool>)
            result = await _result;
          else
            throw AssertionError(_result.runtimeType);

          results.results.add(InterceptorResult(interceptor.name, result));
        }
      } catch (error, stackTrace) {
        errorProcessing(error, stackTrace);
      }

      if (result == true) stopDefaultButtonEvent = true;
    }

    if (stopDefaultButtonEvent)
      return Future<dynamic>.value();
    else {
      results.ifDefaultButtonEventWasFired = true;
      return handlePopRouteFunction();
    }
  }

  static Future<void> _pushRoute(dynamic arguments) =>
      handlePushRouteFunction(arguments as String?);

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

class RouteInfo {
  final Route? routeWhenAdded;

  RouteInfo({this.routeWhenAdded});

  Route? currentRoute(BuildContext context) =>
      BackButtonInterceptor.getCurrentNavigatorRoute(context);

  bool ifRouteChanged(BuildContext context) {
    if (routeWhenAdded == null)
      throw AssertionError("The ifRouteChanged() method "
          "can only be called if the context parameter was "
          "passed to the BackButtonInterceptor.add() method.");

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
    if (zIndex == null && other.zIndex == null)
      return 0;
    else if (zIndex == null && other.zIndex != null)
      return 1;
    else if (zIndex != null && other.zIndex == null)
      return -1;
    else
      return other.zIndex!.compareTo(zIndex!);
  }

  @override
  String toString() =>
      'BackButtonInterceptor: $name, z-index: $zIndex (ifNotYetIntercepted: $ifNotYetIntercepted).';
}

void stableSort<T>(List<T> list,
    {int start = 0, int? end, int Function(T a, T b)? compare}) {
  end ??= list.length;
  compare ??= defaultCompare<T?>();

  int length = end - start;
  if (length < 2) return;
  if (length < _MERGE_SORT_LIMIT) {
    _insertionSort(list, compare: compare, start: start, end: end);
    return;
  }
  int middle = start + ((end - start) >> 1);
  int firstLength = middle - start;
  int secondLength = end - middle;
  var scratchSpace = List<T>.filled(secondLength, list[start]);
  _mergeSort(list, compare, middle, end, scratchSpace, 0);
  int firstTarget = end - firstLength;
  _mergeSort(list, compare, start, middle, list, firstTarget);
  _merge(compare, list, firstTarget, end, scratchSpace, 0, secondLength, list,
      start);
}

/// Returns a [Comparator] that asserts that its first argument is comparable.
Comparator<T> defaultCompare<T>() =>
    (value1, value2) => (value1 as Comparable).compareTo(value2);

/// Limit below which merge sort defaults to insertion sort.
const int _MERGE_SORT_LIMIT = 32;

void _insertionSort<T>(List<T> list,
    {int Function(T a, T b)? compare, int start = 0, int? end}) {
  compare ??= defaultCompare<T>();
  end ??= list.length;

  for (int pos = start + 1; pos < end; pos++) {
    int min = start;
    int max = pos;
    var element = list[pos];
    while (min < max) {
      int mid = min + ((max - min) >> 1);
      int comparison = compare(element, list[mid]);
      if (comparison < 0) {
        max = mid;
      } else {
        min = mid + 1;
      }
    }
    list.setRange(min + 1, pos + 1, list, min);
    list[min] = element;
  }
}

void _movingInsertionSort<T>(List<T> list, int Function(T a, T b) compare,
    int start, int end, List<T> target, int targetOffset) {
  int length = end - start;
  if (length == 0) return;
  target[targetOffset] = list[start];
  for (int i = 1; i < length; i++) {
    var element = list[start + i];
    int min = targetOffset;
    int max = targetOffset + i;
    while (min < max) {
      int mid = min + ((max - min) >> 1);
      if (compare(element, target[mid]) < 0) {
        max = mid;
      } else {
        min = mid + 1;
      }
    }
    target.setRange(min + 1, targetOffset + i + 1, target, min);
    target[min] = element;
  }
}

void _mergeSort<T>(List<T> list, int Function(T a, T b) compare, int start,
    int end, List<T> target, int targetOffset) {
  int length = end - start;
  if (length < _MERGE_SORT_LIMIT) {
    _movingInsertionSort(list, compare, start, end, target, targetOffset);
    return;
  }
  int middle = start + (length >> 1);
  int firstLength = middle - start;
  int secondLength = end - middle;
  int targetMiddle = targetOffset + firstLength;
  _mergeSort(list, compare, middle, end, target, targetMiddle);
  _mergeSort(list, compare, start, middle, list, middle);
  _merge(compare, list, middle, middle + firstLength, target, targetMiddle,
      targetMiddle + secondLength, target, targetOffset);
}

void _merge<T>(
    int Function(T a, T b) compare,
    List<T> firstList,
    int firstStart,
    int firstEnd,
    List<T> secondList,
    int secondStart,
    int secondEnd,
    List<T> target,
    int targetOffset) {
  assert(firstStart < firstEnd);
  assert(secondStart < secondEnd);
  int cursor1 = firstStart;
  int cursor2 = secondStart;
  var firstElement = firstList[cursor1++];
  var secondElement = secondList[cursor2++];
  while (true) {
    if (compare(firstElement, secondElement) <= 0) {
      target[targetOffset++] = firstElement;
      if (cursor1 == firstEnd) break; // Flushing second list after loop.
      firstElement = firstList[cursor1++];
    } else {
      target[targetOffset++] = secondElement;
      if (cursor2 != secondEnd) {
        secondElement = secondList[cursor2++];
        continue;
      }
      target[targetOffset++] = firstElement;
      target.setRange(targetOffset, targetOffset + (firstEnd - cursor1),
          firstList, cursor1);
      return;
    }
  }
  target[targetOffset++] = secondElement;
  target.setRange(
      targetOffset, targetOffset + (secondEnd - cursor2), secondList, cursor2);
}
