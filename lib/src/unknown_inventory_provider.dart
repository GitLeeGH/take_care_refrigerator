import 'dart:async';
import 'package:flutter/widgets.dart';
import 'services/unknown_inventory_pending_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers.dart';
import 'services/candidate_rpc_gateway.dart';
import 'services/expiry_compatibility.dart';
import 'services/unknown_inventory_controller.dart';

/// Only enable after server/legacy-client rollout gates are independently met.
final unknownInventoryEnabledProvider = Provider<bool>(
  (ref) => unknownExpiryReadEnabled,
);

final unknownInventoryWritesEnabledProvider = Provider<bool>(
  (ref) => unknownExpiryRegistrationEnabled,
);

final unknownInventoryControllerProvider =
    Provider.autoDispose<UnknownInventoryController>((ref) {
      if (!ref.watch(unknownInventoryEnabledProvider)) {
        throw StateError('Unknown inventory is not enabled');
      }
      final client = ref.watch(supabaseProvider);
      var epoch = 0;
      var owner = client.auth.currentUser?.id;
      var alive = true;
      final gateway = CandidateRpcGateway.forApp(
        client: client,
        sessionEpoch: () => alive ? epoch : -1,
      );
      final pendingStore = UnknownInventoryPendingStore();
      final controller = UnknownInventoryController(
        restorePending: pendingStore.read,
        retainPending: pendingStore.write,
        clearPending: pendingStore.clear,
        read: gateway.read,
        write: gateway.write,
        owner: () => alive ? client.auth.currentUser?.id : null,
        epoch: () => alive ? epoch : -1,
      );
      final subscription = client.auth.onAuthStateChange.listen((event) {
        final next = event.session?.user.id;
        if (next != owner || event.event == AuthChangeEvent.signedOut) {
          owner = next;
          ++epoch;
          controller.sessionChanged();
          if (owner != null) unawaited(controller.reload());
        }
      });
      final lifecycle = _UnknownInventoryLifecycle(controller);
      WidgetsBinding.instance.addObserver(lifecycle);
      ref.onDispose(() {
        WidgetsBinding.instance.removeObserver(lifecycle);
        alive = false;
        ++epoch;
        subscription.cancel();
        controller.dispose();
      });
      unawaited(controller.reload());
      return controller;
    });

class _UnknownInventoryLifecycle extends WidgetsBindingObserver {
  _UnknownInventoryLifecycle(this.controller);
  final UnknownInventoryController controller;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.reload());
  }
}
