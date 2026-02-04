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

  group('DatabaseService Batch Operations:', () {
    test('Batch insert', () async {
      final newUsers = [
        User(
          id: 'batch001',
          firstName: 'Batch1',
          lastName: 'Test1',
          email: 'batch1@test.com',
          phone: '+359888666777',
          gender: 'M',
          city: 'City1',
          country: 'Country1',
          createdAt: DateTime.now(),
        ),
        User(
          id: 'batch002',
          firstName: 'Batch2',
          lastName: 'Test2',
          email: 'batch2@test.com',
          phone: '+359888777888',
          gender: 'F',
          city: 'City2',
          country: 'Country2',
          createdAt: DateTime.now(),
        ),
      ];

      await userService.insertBatchAsync(newUsers);

      // Verify both users were added
      final user1 = await userService.readAsync('batch001');
      final user2 = await userService.readAsync('batch002');

      expect(user1, isNotNull);
      expect(user2, isNotNull);
    });

    test('Batch update', () async {
      // Create users first
      final users = [
        User(
          id: 'batch_update1',
          firstName: 'Original1',
          lastName: 'Test',
          email: 'update1@test.com',
          phone: '+359888888999',
          gender: 'M',
          city: 'Old City',
          country: 'Country',
          createdAt: DateTime.now(),
        ),
        User(
          id: 'batch_update2',
          firstName: 'Original2',
          lastName: 'Test',
          email: 'update2@test.com',
          phone: '+359888999000',
          gender: 'F',
          city: 'Old City',
          country: 'Country',
          createdAt: DateTime.now(),
        ),
      ];

      await userService.insertBatchAsync(users);

      // Prepare updated versions
      final updatedUsers = users
          .map((u) => u.copyWith(
                city: 'Updated City',
                isVerified: true,
              ))
          .toList();

      await userService.updateBatchAsync(updatedUsers);

      // Verify updates
      for (final user in updatedUsers) {
        final retrieved = await userService.readAsync(user.id);
        expect(retrieved!.city, 'Updated City');
        expect(retrieved.isVerified, true);
      }
    });

    test('Batch delete', () async {
      // Create users for deletion
      final usersToDelete = [
        User(
          id: 'batch_del1',
          firstName: 'Delete1',
          lastName: 'Test',
          email: 'del1@test.com',
          phone: '+359888000111',
          gender: 'M',
          city: 'City',
          country: 'Country',
          createdAt: DateTime.now(),
        ),
        User(
          id: 'batch_del2',
          firstName: 'Delete2',
          lastName: 'Test',
          email: 'del2@test.com',
          phone: '+359888111222',
          gender: 'F',
          city: 'City',
          country: 'Country',
          createdAt: DateTime.now(),
        ),
      ];

      await userService.insertBatchAsync(usersToDelete);

      // Soft delete
      await userService.deleteBatchAsync(['batch_del1', 'batch_del2']);

      // Verify they are deleted
      for (final id in ['batch_del1', 'batch_del2']) {
        final normal = await userService.readAsync(id);
        final withDeleted = await userService.readAsync(id, withDeleted: true);

        expect(normal, isNull);
        expect(withDeleted, isNotNull);
      }
    });

    test('Batch operations with empty list', () async {
      // Should not throw
      await userService.insertBatchAsync([]);
      await userService.updateBatchAsync([]);
      await userService.deleteBatchAsync([]);
      await userService.restoreBatchAsync([]);
    });
  });
}
