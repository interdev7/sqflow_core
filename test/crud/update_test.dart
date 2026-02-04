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

  group('DatabaseService Update Tests:', () {
    test('Update record', () async {
      // Create user first
      final user = User(
        id: 'update_test',
        firstName: 'Original',
        lastName: 'Name',
        email: 'update@test.com',
        phone: '+359888222333',
        gender: 'F',
        city: 'Old City',
        country: 'Old Country',
        createdAt: DateTime.now(),
      );

      await userService.insertAsync(user);

      // Update
      final updatedUser = user.copyWith(
        firstName: 'Updated',
        city: 'New City',
      );

      final rows = await userService.updateAsync(updatedUser);
      expect(rows, 1);

      final retrieved = await userService.readAsync('update_test');
      expect(retrieved!.firstName, 'Updated');
      expect(retrieved.city, 'New City');
    });

    test('Upsert (insert or replace)', () async {
      final user = User(
        id: 'upsert_test',
        firstName: 'Upsert',
        lastName: 'Test',
        email: 'upsert@test.com',
        phone: '+359888333444',
        gender: 'M',
        city: 'City',
        country: 'Country',
        createdAt: DateTime.now(),
      );

      // First time - insert
      await userService.upsertAsync(user);
      var retrieved = await userService.readAsync('upsert_test');
      expect(retrieved!.firstName, 'Upsert');

      // Second time with same id - replace
      final updatedUser = user.copyWith(firstName: 'UpdatedUpsert');
      await userService.upsertAsync(updatedUser);
      retrieved = await userService.readAsync('upsert_test');
      expect(retrieved!.firstName, 'UpdatedUpsert');
    });

    test('Update nonexistent record', () async {
      final nonExistentUser = User(
        id: 'non_existent',
        firstName: 'Non',
        lastName: 'Existent',
        email: 'non@existent.com',
        phone: '+359888444555',
        gender: 'M',
        city: 'City',
        country: 'Country',
        createdAt: DateTime.now(),
      );

      final rows = await userService.updateAsync(nonExistentUser);
      expect(rows, 0);
    });
  });
}
