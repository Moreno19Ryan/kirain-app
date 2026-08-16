import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_worker.dart';

/// Wraps the whole app (see app.dart) to wire up four of ADR-002's five sync
/// triggers — startup, resume, connectivity change, and (indirectly, by
/// existing) manual retry/local-insertion, which call [SyncWorker] directly
/// from wherever they happen rather than through this widget. Purely a
/// trigger source: it never touches outbox rows itself, just tells
/// [SyncWorker] "something changed, take a look."
class SyncLifecycleGate extends ConsumerStatefulWidget {
  const SyncLifecycleGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncLifecycleGate> createState() => _SyncLifecycleGateState();
}

class _SyncLifecycleGateState extends ConsumerState<SyncLifecycleGate> with WidgetsBindingObserver {
  static const _connectivityDebounce = Duration(milliseconds: 500);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Startup trigger.
    unawaited(ref.read(syncWorkerProvider).runStartupSync());

    // Connectivity trigger. Debounced: connectivity_plus can fire several
    // events in quick succession while a radio actually settles, and
    // ADR-002 explicitly doesn't want a ping/HEAD request per event —
    // debouncing collapses a burst into one processQueue() call, and the
    // real Supabase request inside it is what actually proves connectivity,
    // not this stream by itself.
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_connectivityDebounce, () {
        unawaited(ref.read(syncWorkerProvider).processQueue());
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume trigger.
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(syncWorkerProvider).runStartupSync());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The local-insertion trigger: call this right after writing a new item to
/// the outbox (`LocalOutboxRepository.insertPending`, or OFFLINE-003's
/// `LocalFirstTransactionService.recordTransaction`) so a sync attempt
/// starts immediately instead of waiting for the next startup/resume/
/// connectivity event. Fire-and-forget by design — saving locally must not
/// block on network sync.
///
/// Takes [WidgetRef] rather than [Ref]: every real call site is a widget's
/// submit handler (Catat's `_doSubmit`, as of OFFLINE-003), and `WidgetRef`
/// doesn't extend `Ref` in this Riverpod version, so typing this any more
/// broadly than what's actually used would just make the one real caller
/// need an extra cast.
void triggerSyncAfterOutboxInsertion(WidgetRef ref) {
  unawaited(ref.read(syncWorkerProvider).processQueue());
}
