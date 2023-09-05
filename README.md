# handle_navigation_use_case

Example app for flutter issue [#132896](https://github.com/flutter/flutter/issues/132893#issue-1857772748) and pr [132896](https://github.com/flutter/flutter/pull/132896)


## Problem 

In this example application, we use the command "SystemChannels.navigation.setMethodCallHandler(_handleNavigationInvocation)" to capture the back button command coming from the Android operating system. The _handleNavigationInvocation we have set up is actually a copy of the _handleNavigationInvocation method found within Flutter. We use our invocation to prevent the back button event sent from Android. However, within Flutter's invocation, there is an entry called "pushRouteInformation" (_handlePushRouteInformation), which is a private method. Since we cannot copy this method, the deep linking feature that relies on this connection does not work. If SystemChannels.navigation.setMethodCallHandler can be modified at runtime, we need to be able to access its old value, and it should be adjustable. The lines you need to review are back_button_interceptor line: 45,46.