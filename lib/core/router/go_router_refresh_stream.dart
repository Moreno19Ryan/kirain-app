import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a Stream into go_router's [Listenable]-based `refreshListenable`,
/// so the router re-evaluates its `redirect` whenever auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
