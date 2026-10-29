import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/services/ingredient_photo.dart';

class FakeGateway implements IngredientPhotoGateway {
  final removed = <String>[];
  Map<String, dynamic>? row;
  int uploads = 0, saves = 0;
  bool uploadFails = false, responseLost = false, writeFails = false;
  @override
  Future<void> upload(String path, IngredientPhotoDraft photo) async {
    uploads++;
    if (uploadFails) throw StateError('upload failed');
  }

  @override
  Future<Map<String, dynamic>?> read(String id) async => row;
  @override
  Future<void> save(Map<String, dynamic> data, bool editing) async {
    saves++;
    if (writeFails) throw StateError('write failed');
    row = Map.of(data);
    if (responseLost) throw StateError('response lost');
  }

  @override
  Future<void> remove(String path) async => removed.add(path);
}

void main() {
  IngredientPhotoDraft photo() =>
      IngredientPhotoDraft(Uint8List.fromList([255, 216, 255, 0, 0, 0, 0, 0]));
  IngredientSaveOperation operation(FakeGateway gateway) =>
      IngredientSaveOperation(
        gateway: gateway,
        data: {'id': 'ingredient', 'user_id': 'owner', 'name': '두부'},
        editing: true,
        photo: photo(),
        oldPath: 'owner/ingredient/old.jpg',
      );
  test('rejects oversized and unsupported photo content', () {
    expect(
      () => IngredientPhotoDraft(Uint8List(5 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
    expect(() => IngredientPhotoDraft(Uint8List(8)), throwsFormatException);
    expect(photo().mime, 'image/jpeg');
  });
  test(
    'upload failure never creates an ingredient without its photo',
    () async {
      final gateway = FakeGateway()..uploadFails = true;
      await expectLater(operation(gateway).save(), throwsStateError);
      expect(gateway.saves, 0);
      expect(gateway.removed, isNot(contains('owner/ingredient/old.jpg')));
    },
  );
  test(
    'lost committed response is reconciled before old photo cleanup',
    () async {
      final gateway = FakeGateway()..responseLost = true;
      final save = operation(gateway);
      expect(await save.save(), isTrue);
      expect(gateway.saves, 1);
      expect(gateway.removed, ['owner/ingredient/old.jpg']);
      expect(gateway.row!['image_path'], startsWith('owner/ingredient/'));
    },
  );
  test(
    'uncertain write retains candidate and retry uses same identity',
    () async {
      final gateway = FakeGateway()..writeFails = true;
      final save = operation(gateway);
      await expectLater(save.save(), throwsStateError);
      expect(gateway.removed, isEmpty);
      gateway.writeFails = false;
      await save.save();
      expect(gateway.uploads, 1);
      expect(gateway.row!['image_path'], save.data['image_path']);
    },
  );
  test('concurrent button taps share one save', () async {
    final gateway = FakeGateway();
    final save = operation(gateway);
    await Future.wait([save.save(), save.save()]);
    expect(gateway.saves, 1);
    expect(gateway.uploads, 1);
  });
}
