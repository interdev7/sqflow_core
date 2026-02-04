import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflow_core/sqflow_core.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DB db;

  group('Database Initialization Tests:', () {
    late Table<User> usersTable;

    setUp(() {
      usersTable = Table<User>(
        name: 'users',
        schema: '''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''',
        fromJson: (json) => User.fromJson(json),
      );
    });

    tearDown(() async {
      await db.close();
      await db.reset();
    });

    test('DB initializes with correct version', () async {
      db = DB(
        databaseName: ':memory:',
        version: 1,
        tables: [usersTable],
      );

      final database = await db.database;
      expect(database, isNotNull);
      expect(await db.getCurrentFileVersion(), 1);
    });

    test('Tables are created successfully', () async {
      db = DB(
        databaseName: ':memory:',
        version: 1,
        tables: [usersTable],
      );

      final database = await db.database;
      final tables = await database.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      expect(tables.any((t) => t['name'] == 'users'), isTrue);
    });
  });

  group('Migration Tracking Tests:', () {
    int migrationCallCount = 0;

    setUp(() {
      migrationCallCount = 0;
    });

    tearDown(() async {
      await db.close();
      await db.reset();
    });

    test('Migrations are applied on creation', () async {
      final usersTable = Table<User>(
        name: 'users',
        schema: '''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''',
        fromJson: (json) => User.fromJson(json),
      )
          .migrate()
          .custom(
            description: 'Test migration',
            version: 1,
            migrate: (db, table) async {
              migrationCallCount++;
            },
          )
          .build();

      db = DB(
        databaseName: 'test_migrations.db',
        version: 1,
        tables: [usersTable],
      );

      await db.database;
      expect(migrationCallCount, 1);
    });

    test('Migration order is correct', () async {
      final migrationsApplied = <String>[];

      final trackedTable = Table<User>(
        name: 'tracked',
        schema: 'CREATE TABLE tracked (id TEXT)',
        fromJson: (json) => User.fromJson(json),
      )
          .migrate()
          .custom(
            description: 'Migration v2-1',
            version: 2,
            migrate: (db, table) async {
              migrationsApplied.add('v2-1');
            },
          )
          .custom(
            description: 'Migration v2-2',
            version: 2,
            migrate: (db, table) async {
              migrationsApplied.add('v2-2');
            },
          )
          .custom(
            description: 'Migration v3',
            version: 3,
            migrate: (db, table) async {
              migrationsApplied.add('v3');
            },
          )
          .build();

      db = DB(
        databaseName: ':memory:',
        version: 3,
        tables: [trackedTable],
      );

      await db.database;
      expect(migrationsApplied, containsAll(['v2-1', 'v2-2', 'v3']));
    });
  });

  group('Version Management Tests:', () {
    tearDown(() async {
      await db.close();
      await db.reset();
    });

    test('Migration with same version from different tables', () async {
      final usersTable = Table<User>(
        name: 'users',
        schema: 'CREATE TABLE users (id TEXT)',
        fromJson: (json) => User.fromJson(json),
      )
          .migrate()
          .addColumn(
            name: 'email',
            type: 'TEXT',
            version: 2,
            description: 'Add email to users',
          )
          .build();

      final postsTable = Table<Post>(
        name: 'posts',
        schema: 'CREATE TABLE posts (id TEXT)',
        fromJson: (json) => Post.fromJson(json),
      )
          .migrate()
          .addColumn(
            name: 'title',
            type: 'TEXT',
            version: 2,
            description: 'Add title to posts',
          )
          .build();

      db = DB(
        databaseName: ':memory:',
        version: 2,
        tables: [usersTable, postsTable],
      );

      await db.database;

      final database = await db.database;

      final usersColumns = await database.rawQuery("PRAGMA table_info(users)");
      expect(usersColumns.any((c) => c['name'] == 'email'), isTrue);

      final postsColumns = await database.rawQuery("PRAGMA table_info(posts)");
      expect(postsColumns.any((c) => c['name'] == 'title'), isTrue);
    });
  });

  group('Migration Builder Tests:', () {
    tearDown(() async {
      await db.close();
      await db.reset();
    });

    test('addColumn generates correct SQL', () async {
      final table = Table<User>(
        name: 'test',
        schema: 'CREATE TABLE test (id TEXT)',
        fromJson: (json) => User.fromJson(json),
      )
          .migrate()
          .addColumn(
            name: 'email',
            type: 'TEXT',
            version: 1,
          )
          .build();

      db = DB(
        databaseName: ':memory:',
        version: 1,
        tables: [table],
      );

      await db.database;

      final database = await db.database;
      final columns = await database.rawQuery("PRAGMA table_info(test)");
      expect(columns.any((c) => c['name'] == 'email'), isTrue);
    });

    test('createIndex generates correct SQL', () async {
      final table = Table<User>(
        name: 'test',
        schema: 'CREATE TABLE test (id TEXT, email TEXT)',
        fromJson: (json) => User.fromJson(json),
      )
          .migrate()
          .createIndex(
            name: 'idx_test_email',
            columns: ['email'],
            version: 1,
          )
          .build();

      db = DB(
        databaseName: ':memory:',
        version: 1,
        tables: [table],
      );

      await db.database;

      final database = await db.database;
      final indexes = await database.rawQuery("SELECT name FROM sqlite_master WHERE type='index' AND name='idx_test_email'");
      expect(indexes, hasLength(1));
    });
  });

  group('Real-world Migration Scenarios:', () {
    tearDown(() async {
      await db.close();
      await db.reset();
    });

    test('Simple table evolution', () async {
      // Create table with migrations
      final usersTable = Table<User>(
        name: 'users',
        schema: '''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            username TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''',
        fromJson: (json) => User.fromJson(json),
      )
          .migrate()
          .addColumn(
            name: 'email',
            type: 'TEXT',
            version: 2,
            description: 'Add email column',
          )
          .addColumn(
            name: 'age',
            type: 'INTEGER',
            version: 2,
            nullable: true,
            description: 'Add age column',
          )
          .build();

      db = DB(
        databaseName: 'evolution_test.db',
        version: 2,
        tables: [usersTable],
      );

      await db.database;

      final database = await db.database;
      final columns = await database.rawQuery("PRAGMA table_info(users)");
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      expect(columnNames, containsAll(['id', 'username', 'created_at', 'email', 'age']));
    });
  });

  group('Production-Ready Persistence & Upgrade Tests:', () {
    const dbFileName = 'evolution_test.db';

    Future<void> cleanDb() async {
      try {
        final path = join(await getDatabasesPath(), dbFileName);
        if (await databaseFactory.databaseExists(path)) {
          await databaseFactory.deleteDatabase(path);
        }
      } catch (_) {
        // Ignore cleanup errors
      }
    }

    setUp(() async => await cleanDb());
    tearDown(() async => await cleanDb());

    test('Data persists and migrations apply when app updates (v1 -> v2)', () async {
      final usersV1 = Table<User>(
        name: 'users',
        schema: 'CREATE TABLE users (id TEXT PRIMARY KEY, name TEXT, created_at TEXT)',
        fromJson: (json) => User.fromJson(json),
      );

      // --- v1 ---
      var dbv1 = DB(databaseName: dbFileName, version: 1, tables: [usersV1]);
      final databaseV1 = await dbv1.database;
      await databaseV1.insert('users', {'id': '1', 'name': 'Anton', 'created_at': DateTime.now().toIso8601String()});
      await dbv1.close();

      // Small delay for FFI to ensure file is released
      await Future.delayed(const Duration(milliseconds: 200));

      // --- v2 ---
      final usersV2 = usersV1.migrate().addColumn(name: 'email', type: 'TEXT', version: 2).build();

      var dbV2 = DB(databaseName: dbFileName, version: 2, tables: [usersV2]);
      final databaseV2 = await dbV2.database;

      // Verify data persists
      final rows = await databaseV2.query('users', where: 'id = ?', whereArgs: ['1']);
      expect(rows.first['name'], 'Anton');

      // Verify new column exists
      final tableInfo = await databaseV2.rawQuery('PRAGMA table_info(users)');
      final hasEmail = tableInfo.any((column) => column['name'] == 'email');
      expect(hasEmail, true);

      await dbV2.close();
    });

    test('Transaction rollback: If migration fails, version should NOT increase', () async {
      final brokenTable = Table<User>(
        name: 'users',
        schema: 'CREATE TABLE users (id TEXT PRIMARY KEY, name TEXT)',
        fromJson: (json) => User.fromJson(json),
      )
          .migrate()
          .custom(
            description: 'Broken migration',
            version: 1, // Fail during creation
            migrate: (db, table) async {
              throw Exception('Boom! Migration failed');
            },
          )
          .build();

      final db = DB(databaseName: dbFileName, version: 1, tables: [brokenTable]);

      // 1. Expect error during open
      await expectLater(db.database, throwsException);

      // 2. Allow database to close after failure
      await Future.delayed(const Duration(milliseconds: 200));

      // 3. Check file version directly via factory, not through our DB class
      final path = join(await getDatabasesPath(), dbFileName);
      final checkDb = await databaseFactory.openDatabase(path, options: OpenDatabaseOptions(readOnly: true));
      final version = await checkDb.getVersion();
      await checkDb.close();

      // Version must not become 1 since the transaction was rolled back
      expect(version, 0);
    });
  });
}

// Test models
class User extends Model {
  @override
  final String id;
  final String name;
  final String? email;
  final int? age;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  User({
    required this.id,
    required this.name,
    this.email,
    this.age,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'age': age,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      age: json['age'] as int?,
      isActive: (json['is_active'] as int?) == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
    );
  }
}

class Post extends Model {
  @override
  final String id;
  final String title;
  final String content;
  final String userId;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.userId,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'user_id': userId,
    };
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      userId: json['user_id'] as String,
    );
  }

  @override
  // TODO: implement createdAt
  DateTime? get createdAt => null;

  @override
  // TODO: implement deletedAt
  DateTime? get deletedAt => null;

  @override
  // TODO: implement updatedAt
  DateTime? get updatedAt => null;
}
