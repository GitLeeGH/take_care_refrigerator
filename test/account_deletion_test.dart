import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/services/account_deletion.dart';

void main() {
  for (final failedStep in [0, 1]) {
    test(
      'server failure at step $failedStep never completes locally',
      () async {
        final calls = <String>[];
        await expectLater(
          deleteAccountSafely(
            deleteData: () async {
              calls.add('data');
              if (failedStep == 0) throw StateError('offline');
              return null;
            },
            deleteIdentity: () async {
              calls.add('identity');
              throw StateError('denied');
            },
            onConfirmed: () async {
              calls.add('local-success');
            },
          ),
          throwsStateError,
        );
        expect(calls, failedStep == 0 ? ['data'] : ['data', 'identity']);
      },
    );
  }
  test('explicit server rejection never completes locally', () async {
    var completed = false;
    await expectLater(
      deleteAccountSafely(
        deleteData: () async => null,
        deleteIdentity: () async => {'success': false},
        onConfirmed: () async {
          completed = true;
        },
      ),
      throwsStateError,
    );
    expect(completed, isFalse);
  });
  test('completion runs only after both server calls succeed', () async {
    final calls = <String>[];
    await deleteAccountSafely(
      deleteData: () async {
        calls.add('data');
        return null;
      },
      deleteIdentity: () async {
        calls.add('identity');
        return null;
      },
      onConfirmed: () async {
        calls.add('local-success');
      },
    );
    expect(calls, ['data', 'identity', 'local-success']);
  });
}
