import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'services/local_expiry_reminders.dart';

final localExpiryControllerProvider = Provider<LocalExpiryController>((ref) {
  final controller = LocalExpiryController(NativeLocalExpiryPlatform());
  ref.onDispose(controller.dispose);
  return controller;
});

/// Uses the single foreground authenticated client; no second refresh writer.
final localExpiryDatesReaderProvider =
    Provider<Future<List<String>> Function(String)>((ref) {
      final client = ref.watch(supabaseProvider);
      return (owner) async {
        if (client.auth.currentUser?.id != owner)
          throw StateError('Account changed');
        final rows = await client
            .from('ingredients')
            .select('id,user_id,expiry_date,quantity')
            .eq('user_id', owner)
            .limit(501)
            .timeout(const Duration(seconds: 10));
        if (client.auth.currentUser?.id != owner)
          throw StateError('Account changed');
        return localExpiryDatesFromRows(rows, owner);
      };
    });

final localExpirySyncProvider = Provider.autoDispose<void>((ref) {
  final controller = ref.watch(localExpiryControllerProvider);
  final client = ref.watch(supabaseProvider);
  final owner = client.auth.currentUser?.id;
  if (owner == null || !controller.platform.supported) return;
  var alive = true, sequence = 0;
  void synchronize() {
    if (localExpiryMutationInProgress(owner)) return;
    final request = ++sequence, epoch = localExpiryMutationEpoch(owner);
    bool current() =>
        alive &&
        request == sequence &&
        client.auth.currentUser?.id == owner &&
        !localExpiryMutationInProgress(owner) &&
        localExpiryMutationEpoch(owner) == epoch;
    controller.reconcile(
      owner: owner,
      query: () => ref.read(localExpiryDatesReaderProvider)(owner),
      current: current,
    );
  }

  ref.listen(ingredientsProvider, (_, next) {
    if (next.hasValue && !next.isLoading && !next.hasError) synchronize();
  }, fireImmediately: true);
  final lifecycle = _LocalExpiryLifecycle(synchronize);
  WidgetsBinding.instance.addObserver(lifecycle);
  localExpiryMutationEvents.addListener(synchronize);
  ref.onDispose(() {
    alive = false;
    WidgetsBinding.instance.removeObserver(lifecycle);
    localExpiryMutationEvents.removeListener(synchronize);
  });
});

class _LocalExpiryLifecycle extends WidgetsBindingObserver {
  _LocalExpiryLifecycle(this.resume);
  final VoidCallback resume;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) resume();
  }
}
