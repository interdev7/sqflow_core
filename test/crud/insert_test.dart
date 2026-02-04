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

  group('DatabaseService Insert Tests:', () {
    test('Insert and read single record', () async {
      final newUser = User(
        id: 'test001',
        firstName: 'Test',
        lastName: 'User',
        email: 'test@example.com',
        phone: '+359888111222',
        gender: 'M',
        city: 'Test City',
        country: 'Test Country',
        createdAt: DateTime.now(),
      );

      final id = await userService.insertAsync(newUser);
      expect(id, greaterThan(0));

      final retrieved = await userService.readAsync('test001');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'test001');
      expect(retrieved.email, 'test@example.com');
    });
  });
}
