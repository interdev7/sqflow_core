import 'common.dart';

void main() {
  late DatabaseService<User> userService;

  setUpAll(() {
    initSqflite();
  });

  setUp(() async {
    userService = await createTestService();
  });

  tearDown(() async {
    final db = await userService.database;
    await db.close();
  });

  group('DatabaseService Read Tests:', () {
    test('Existence check', () async {
      // Existing user (seeded in createTestService)
      final exists = await userService.existsAsync('u001');
      expect(exists, true);

      // Nonexistent user
      final notExists = await userService.existsAsync('nonexistent');
      expect(notExists, false);

      // Deleted user (without withDeleted)
      await userService.deleteAsync('u002');
      final deletedExists = await userService.existsAsync('u002');
      expect(deletedExists, false);

      // Deleted user (with withDeleted)
      final deletedExistsWith = await userService.existsAsync(
        'u002',
        withDeleted: true,
      );
      expect(deletedExistsWith, true);
    });

    test('Read nonexistent record', () async {
      final user = await userService.readAsync('nonexistent_id');
      expect(user, isNull);
    });
  });
}
