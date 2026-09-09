import 'package:flutter/material.dart';

import 'debug_log.dart';

/// Автослед навигации для мега-логера: видно, на каком экране
/// происходят пики, без ручных пометок.
class DebugNavObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    DebugLog.log('NAV push ${route.settings.name ?? route.runtimeType}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    DebugLog.log('NAV pop ${route.settings.name ?? route.runtimeType}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    DebugLog.log('NAV remove ${route.settings.name ?? route.runtimeType}');
  }
}
