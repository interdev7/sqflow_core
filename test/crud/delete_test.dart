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

  group('DatabaseService Delete/Restore Tests:', () {
    test('Soft delete and restore', () async {
      final user = User(
        id: 'soft_delete_test',
        firstName: 'Soft',
        lastName: 'Delete',
        email: 'soft.delete@test.com',
        phone: '+359888444555',
        gender: 'F',
        city: 'City',
        country: 'Country',
        createdAt: DateTime.now(),
      );

      await userService.insertAsync(user);

      // Soft delete
      final deleteRows = await userService.deleteAsync('soft_delete_test');
      expect(deleteRows, 1);

      // Verify user not present in normal read
      final normalRead = await userService.readAsync('soft_delete_test');
      expect(normalRead, isNull);

      // Verify user available with withDeleted
      final withDeletedRead = await userService.readAsync(
        'soft_delete_test',
        withDeleted: true,
      );
      expect(withDeletedRead, isNotNull);
      expect(withDeletedRead!.deletedAt, isNotNull);

      // Restore
      final restoreRows = await userService.restoreAsync('soft_delete_test');
      expect(restoreRows, 1);

      final restored = await userService.readAsync('soft_delete_test');
      expect(restored, isNotNull);
      expect(restored!.deletedAt, isNull);
    });

    test('Force delete (hard delete)', () async {
      final user = User(
        id: 'force_delete_test',
        firstName: 'Force',
        lastName: 'Delete',
        email: 'force.delete@test.com',
        phone: '+359888555666',
        gender: 'M',
        city: 'City',
        country: 'Country',
        createdAt: DateTime.now(),
      );

      await userService.insertAsync(user);

      // Hard delete
      final deleteRows = await userService.deleteAsync(
        'force_delete_test',
        force: true,
      );
      expect(deleteRows, 1);

      // Verify user absent even with withDeleted
      final read = await userService.readAsync(
        'force_delete_test',
        withDeleted: true,
      );
      expect(read, isNull);
    });

    test('Delete nonexistent record', () async {
      final rows = await userService.deleteAsync('non_existent');
      expect(rows, 0);
    });

    test('Restore nonexistent record', () async {
      final rows = await userService.restoreAsync('non_existent');
      expect(rows, 0);
    });
  });
}
