import 'package:take_care_refrigerator/src/services/meal_history.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/services/curation_preferences.dart';

// Existing screen tests use an empty local store, never device storage.
void stubLocalPreferences() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceMealStorage.channel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          CurationPreferenceStore.channel,
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceMealStorage.channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CurationPreferenceStore.channel, null);
  });
}

class TestCurationIdentity implements CurationIdentity {
  TestCurationIdentity([this.account = 'account-a']);
  @override
  String? account;
  final events = StreamController<void>.broadcast(sync: true);
  @override
  Stream<void> get changes => events.stream;
  void switchTo(String? value) {
    account = value;
    events.add(null);
  }
}

final testCurationIdentityOverride = curationIdentityProvider.overrideWith((
  ref,
) {
  final identity = TestCurationIdentity();
  ref.onDispose(identity.events.close);
  return identity;
});
