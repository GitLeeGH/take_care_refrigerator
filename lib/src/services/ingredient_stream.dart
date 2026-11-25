import 'dart:async';
import '../models.dart';

/// Bound the first snapshot only. A quiet live inventory is not a failure.
/// Timeout/error does not fabricate an empty inventory; a later snapshot may recover.
Stream<List<Ingredient>> accountIngredientStream(
  Stream<List<Map<String, dynamic>>> rows,
  String owner,
  String? Function() currentOwner,
) {
  StreamSubscription<List<Map<String, dynamic>>>? subscription;
  Timer? firstResponse;
  late StreamController<List<Ingredient>> output;
  bool current() => !output.isClosed && currentOwner() == owner;
  output = StreamController<List<Ingredient>>(
    onListen: () {
      firstResponse = Timer(const Duration(seconds: 30), () {
        if (current()) {
          output.addError(
            TimeoutException('Inventory initial response timed out'),
          );
        }
      });
      subscription = rows.listen(
        (data) {
          firstResponse?.cancel();
          if (!current()) return;
          try {
            output.add(data.map(Ingredient.fromJson).toList());
          } catch (error, stack) {
            output.addError(error, stack);
          }
        },
        onError: (Object error, StackTrace stack) {
          firstResponse?.cancel();
          if (current()) output.addError(error, stack);
        },
        onDone: () {
          firstResponse?.cancel();
          if (current()) output.addError(StateError('Inventory stream closed'));
          unawaited(output.close());
        },
      );
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () {
      firstResponse?.cancel();
      return subscription?.cancel();
    },
  );
  return output.stream;
}
