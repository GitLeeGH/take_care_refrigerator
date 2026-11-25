/// Local completion is permitted only after both server operations succeed.
/// A partial deletion is not rolled back; failures must remain retryable.
Future<void> deleteAccountSafely({
  required Future<Object?> Function() deleteData,
  required Future<Object?> Function() deleteIdentity,
  required Future<void> Function() onConfirmed,
  bool Function()? stillCurrent,
}) async {
  void checkOwner() {
    if (!(stillCurrent?.call() ?? true)) {
      throw StateError('Account changed during deletion');
    }
  }

  for (final operation in [deleteData, deleteIdentity]) {
    checkOwner();
    final result = await operation();
    checkOwner();
    if (result == false ||
        (result is Map &&
            (result['success'] == false || result['error'] != null))) {
      throw StateError('Server did not confirm account deletion');
    }
  }
  checkOwner();
  await onConfirmed();
}
