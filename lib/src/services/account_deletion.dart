/// Local completion is permitted only after both server operations succeed.
/// A partial deletion is not rolled back; failures must remain retryable.
Future<void> deleteAccountSafely({
  required Future<Object?> Function() deleteData,
  required Future<Object?> Function() deleteIdentity,
  required Future<void> Function() onConfirmed,
}) async {
  for (final operation in [deleteData, deleteIdentity]) {
    final result = await operation();
    if (result == false ||
        (result is Map &&
            (result['success'] == false || result['error'] != null))) {
      throw StateError('Server did not confirm account deletion');
    }
  }
  await onConfirmed();
}
