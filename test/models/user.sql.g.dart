// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// SqlSchemaGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// SQL schema for table: users

part of 'user.dart';

const _schema = """
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
""";

class _UserTable extends Table<User> {
  _UserTable({
    required super.schema,
    required super.name,
    required super.fromJson,
  }) : super(paranoid: _detectSoftDelete(schema));
}

bool _detectSoftDelete(String schema) {
  final normalized = schema.toLowerCase();
  return normalized.contains('deleted_at') && normalized.contains('create table');
}

final _$usersTable = _UserTable(
  schema: _schema,
  name: 'users',
  fromJson: User.fromJson,
);
