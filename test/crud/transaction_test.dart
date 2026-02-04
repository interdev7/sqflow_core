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

  group('DatabaseService Transaction:', () {
    test('Transaction rolls back on error', () async {
      final initialCount = (await userService.readAll()).count;

      try {
        await userService.transaction((txn) async {
          // Insert a new user
          await txn.insert('users', {
            'id': 'txn_test',
            'first_name': 'Transaction',
            'last_name': 'Test',
            'email': 'txn@test.com',
            'phone': '+359888222333',
            'gender': 'M',
            'city': 'City',
            'country': 'Country',
            'is_active': 1,
            'is_verified': 0,
            'created_at': DateTime.now().toIso8601String(),
          });

          // Simulate an error
          throw Exception('Test rollback');
        });
      } catch (_) {
        // Ignore expected error
      }

      // Verify transaction rolled back
      final finalCount = (await userService.readAll()).count;
      expect(finalCount, initialCount);

      // Verify user was not inserted
      final user = await userService.readAsync('txn_test');
      expect(user, isNull);
    });

    test('Successful transaction', () async {
      final initialCount = (await userService.readAll()).count;

      await userService.transaction((txn) async {
        // Insert a user
        await txn.insert('users', {
          'id': 'txn_success',
          'first_name': 'Success',
          'last_name': 'Transaction',
          'email': 'success.txn@test.com',
          'phone': '+359888333444',
          'gender': 'F',
          'city': 'City',
          'country': 'Country',
          'is_active': 1,
          'is_verified': 1,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Update an existing user
        await txn.update(
          'users',
          {'first_name': 'UpdatedInTxn'},
          where: 'id = ?',
          whereArgs: ['u001'],
        );
      });

      // Verify both changes were applied
      final finalCount = (await userService.readAll()).count;
      expect(finalCount, initialCount + 1);

      final newUser = await userService.readAsync('txn_success');
      expect(newUser, isNotNull);
      expect(newUser!.email, 'success.txn@test.com');

      final updatedUser = await userService.readAsync('u001');
      expect(updatedUser!.firstName, 'UpdatedInTxn');
    });
  });
}
