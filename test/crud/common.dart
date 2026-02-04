import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflow_core/sqflow_core.dart';
import '../models/user.dart';
import '../mock_users.dart';

// Re-export needed packages
export 'package:flutter_test/flutter_test.dart';
export 'package:sqflite_common_ffi/sqflite_ffi.dart';
export 'package:sqflow_core/sqflow_core.dart';
export '../models/user.dart';
export '../mock_users.dart';

void initSqflite() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

Table<User> createUsersTable() {
  return Table<User>(
    name: 'users',
    schema: '''
      CREATE TABLE users (
        id TEXT PRIMARY KEY NOT NULL UNIQUE,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        phone TEXT NOT NULL,
        birth_date TEXT,
        age INTEGER,
        gender TEXT NOT NULL CHECK(gender IN ('M', 'F', 'Other')),
        city TEXT NOT NULL,
        country TEXT NOT NULL,
        address TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_verified INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT
      );

      CREATE UNIQUE INDEX users_email_idx ON users(email);
      CREATE INDEX users_first_name_last_name_idx ON users(first_name, last_name);
    ''',
    fromJson: User.fromJson,
    paranoid: true,
  );
}

Future<DatabaseService<User>> createTestService() async {
  final usersTable = createUsersTable();
  // Using a fresh in-memory database for each test service instance
  // Note: 'memory' with no name might share instance? No, ':memory:' is unique per connection if opened separately,
  // but here we want to ensure isolation.
  // In crud_service_test.dart it used ':memory:'.
  final dbManager = DB(databaseName: ':memory:', version: 1, tables: [usersTable]);
  final userService = DatabaseService<User>(dbManager: dbManager, table: usersTable);

  // Seed initial data
  await userService.insertBatchAsync(mockUsers);

  return userService;
}
