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

  group('DatabaseService ReadAll Tests:', () {
    test('Basic pagination', () async {
      final result = await userService.readAll(
        limit: 5,
        offset: 0,
      );

      expect(result.data.length, 5);
      expect(result.count, greaterThan(5));
      expect(result.data[0], isA<User>());
    });

    test('Filtering with conditions', () async {
      final where = WhereBuilder().eq('gender', 'M').gt('age', 40).eq('city', 'Sofia');

      final result = await userService.readAll(
        limit: 10,
        where: where,
      );

      // Verify all returned users match the conditions
      for (final user in result.data) {
        expect(user.gender, 'M');
        expect(user.age, greaterThan(40));
        expect(user.city, 'Sofia');
      }
    });

    test('Sorting', () async {
      final sort = SortBuilder().asc('last_name').desc('age');

      final result = await userService.readAll(
        limit: 10,
        sort: sort,
      );

      // Verify the data is sorted
      for (var i = 0; i < result.data.length - 1; i++) {
        final current = result.data[i];
        final next = result.data[i + 1];

        // Check sorting by last name (asc)
        expect(
          current.lastName.compareTo(next.lastName) <= 0,
          true,
          reason: '${current.lastName} should come before ${next.lastName}',
        );

        // When last names are equal, check age sorting (desc)
        if (current.lastName == next.lastName) {
          expect(
            (current.age ?? 0) >= (next.age ?? 0),
            true,
            reason: 'When last names are equal (${current.lastName}), '
                'age should be descending: ${current.age} >= ${next.age}',
          );
        }
      }
    });

    test('readAll with LENGTH and SUBSTR filters', () async {
      initSqflite();
      final service = await createTestService();

      final result = await service.readAll(
        where: WhereBuilder().lengthEq('first_name', 5).substrEq('last_name', 1, 1, 'S'),
        limit: 50,
      );

      // Expect at least one match (James Smith - u001)
      expect(result.count, greaterThanOrEqualTo(1));
      final ids = result.data.map((e) => e.id).toList();
      expect(ids, contains('u001'));
    });

    test('readAll with OR and AND group filters', () async {
      initSqflite();
      final service = await createTestService();

      final where = WhereBuilder().andGroup((ag) {
        ag.eq('country', 'Bulgaria').lengthGt('first_name', 4);
      }).orGroup((og) {
        og.substrLike('email', 1, 3, '%@g').eq('city', 'Varna');
      });

      final result = await service.readAll(where: where, limit: 50);

      expect(result.count, greaterThanOrEqualTo(1));
      final ids = result.data.map((e) => e.id).toList();
      expect(ids, contains('u003'));
    });

    test('Only deleted records', () async {
      // First mark some users as deleted
      await userService.deleteAsync('u001');
      await userService.deleteAsync('u002');

      final result = await userService.readAll(
        limit: 10,
        onlyDeleted: true,
      );

      expect(result.data.length, greaterThan(0));

      for (final user in result.data) {
        expect(user.deletedAt, isNotNull);
      }
    });

    test('Search across multiple columns', () async {
      final where = WhereBuilder().orGroup((og) {
        og.like('first_name', '%James%').like('last_name', '%Smith%').like('email', '%gmail.com');
      });

      final result = await userService.readAll(
        limit: 10,
        where: where,
      );

      expect(result.data.length, greaterThan(0));

      for (final user in result.data) {
        final matches = user.firstName.contains('James') || user.lastName.contains('Smith') || user.email.contains('gmail.com');

        expect(matches, true);
      }
    });

    test('Combined conditions with AND and OR', () async {
      final where = WhereBuilder().eq('is_active', 1).andGroup((ag) {
        ag.gt('age', 25).lt('age', 40);
      }).orGroup((og) {
        og.eq('city', 'Sofia').eq('city', 'Plovdiv');
      });

      final result = await userService.readAll(
        limit: 20,
        where: where,
      );

      for (final user in result.data) {
        expect(user.isActive, true);
        expect(user.age, greaterThan(25));
        expect(user.age, lessThan(40));
        expect(user.city == 'Sofia' || user.city == 'Plovdiv', true);
      }
    });
  });
}
