import 'common.dart';

void main() {
  group('Indexes and CHECK constraint tests:', () {
    test('Indexes exist and have correct columns', () async {
      initSqflite();
      final service = await createTestService();
      final db = await service.dbManager.database;

      final idxList = await db.rawQuery("PRAGMA index_list('users')");
      final indexNames = idxList.map((r) => r['name'] as String).toList();

      expect(indexNames, contains('users_email_idx'));
      expect(indexNames, contains('users_first_name_last_name_idx'));

      final info = await db.rawQuery("PRAGMA index_info('users_first_name_last_name_idx')");
      final cols = info.map((r) => r['name'] as String).toList();
      expect(cols, equals(['first_name', 'last_name']));
    });

    test('CHECK constraint rejects invalid gender', () async {
      initSqflite();
      final service = await createTestService();

      final badUser = User(
        id: 'bad_gender_001',
        firstName: 'Bad',
        lastName: 'Gender',
        email: 'bad.gender@example.com',
        phone: '+359000000000',
        birthDate: null,
        age: 99,
        gender: 'X', // invalid per CHECK
        city: 'Nowhere',
        country: 'Bulgaria',
        createdAt: DateTime.now(),
      );

      expect(
        () async => await service.insertAsync(badUser),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
