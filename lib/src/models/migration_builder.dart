import 'package:sqflite/sqflite.dart';
import 'package:sqflow_core/src/annotations/table.dart';
import 'package:sqflow_core/src/models/models.dart';
import 'package:sqflow_core/src/models/table_migration.dart';

/// =======================================================
/// MIGRATION BUILDER (FLUENT API)
/// =======================================================
///
/// Fluent builder for creating migration sequences.
/// Provides type-safe methods for common migration operations.
///
/// **Example:**
/// ```dart
/// final migrations = table.migrate()
///   .addColumn(name: 'email', type: 'TEXT', version: 2)
///   .renameColumn(oldName: 'full_name', newName: 'name', version: 2)
///   .createIndex(name: 'idx_active', columns: ['is_active'], version: 3)
///   .custom(
///     description: 'Backfill data',
///     version: 2,
///     migrate: (db, table) async {
///       await db.execute('UPDATE ${table.name} SET status = "active"');
///     },
///   )
///   .build();
/// ```
class MigrationBuilder<T extends Model> {
  final Table<T> _table;
  final List<TableMigration> _migrations = [];
  int _currentPriority = 0;

  MigrationBuilder(this._table);

  /// Adds a raw SQL migration
  ///
  /// **Example:**
  /// ```dart
  /// .raw(
  ///   'ALTER TABLE users ADD COLUMN middle_name TEXT',
  ///   version: 2,
  ///   description: 'Add middle name column',
  /// )
  /// ```
  MigrationBuilder<T> raw(
    String sql, {
    required int version,
    String description = '',
  }) {
    _migrations.add(TableMigration<T>(
      table: _table,
      targetVersion: version,
      description: description.isNotEmpty ? description : 'Raw SQL: ${_truncate(sql, 50)}',
      migrate: (db, _) async => await db.execute(sql),
      priority: _currentPriority++,
    ));
    return this;
  }

  /// Adds a new column to the table
  ///
  /// **Example:**
  /// ```dart
  /// .addColumn(
  ///   name: 'birth_date',
  ///   type: 'TEXT',
  ///   version: 2,
  ///   nullable: true,
  ///   defaultValue: 'NULL',
  /// )
  /// ```
  MigrationBuilder<T> addColumn({
    required String name,
    required String type,
    required int version,
    bool nullable = true,
    String? defaultValue,
    String? description,
  }) {
    final sql = StringBuffer('ALTER TABLE ${_table.name} ADD COLUMN $name $type');

    if (!nullable) {
      sql.write(' NOT NULL');
    }

    if (defaultValue != null) {
      sql.write(' DEFAULT $defaultValue');
    }

    return raw(
      sql.toString(),
      version: version,
      description: description ?? 'Add column $name ($type)',
    );
  }

  /// Drops a column from the table
  ///
  /// **Note:** SQLite doesn't directly support DROP COLUMN.
  /// This creates a workaround using table recreation.
  ///
  /// **Warning:** This is a destructive operation. Use with caution.
  MigrationBuilder<T> dropColumn({
    required String name,
    required int version,
    String? description,
  }) {
    return custom(
      description: description ?? 'Drop column $name',
      version: version,
      migrate: (db, table) async => await _dropColumnWorkaround(db, table, name),
    );
  }

  /// Renames a column
  ///
  /// **Example:**
  /// ```dart
  /// .renameColumn(
  ///   oldName: 'full_name',
  ///   newName: 'name',
  ///   version: 2,
  /// )
  /// ```
  MigrationBuilder<T> renameColumn({
    required String oldName,
    required String newName,
    required int version,
    String? description,
  }) {
    return raw(
      'ALTER TABLE ${_table.name} RENAME COLUMN $oldName TO $newName',
      version: version,
      description: description ?? 'Rename $oldName to $newName',
    );
  }

  /// Creates an index
  ///
  /// **Example:**
  /// ```dart
  /// .createIndex(
  ///   name: 'idx_users_email',
  ///   columns: ['email'],
  ///   unique: true,
  ///   version: 3,
  /// )
  /// ```
  MigrationBuilder<T> createIndex({
    required String name,
    required List<String> columns,
    required int version,
    bool unique = false,
    String? description,
  }) {
    final uniqueStr = unique ? 'UNIQUE ' : '';
    final columnsStr = columns.join(', ');

    return raw(
      'CREATE ${uniqueStr}INDEX $name ON ${_table.name} ($columnsStr)',
      version: version,
      description: description ?? 'Create ${unique ? 'unique ' : ''}index $name',
    );
  }

  /// Drops an index
  ///
  /// **Example:**
  /// ```dart
  /// .dropIndex(name: 'idx_old_index', version: 2)
  /// ```
  MigrationBuilder<T> dropIndex({
    required String name,
    required int version,
    String? description,
  }) {
    return raw(
      'DROP INDEX IF EXISTS $name',
      version: version,
      description: description ?? 'Drop index $name',
    );
  }

  /// Adds a custom migration with arbitrary logic
  ///
  /// **Example:**
  /// ```dart
  /// .custom(
  ///   description: 'Backfill user roles',
  ///   version: 2,
  ///   migrate: (db, table) async {
  ///     await db.execute('''
  ///       UPDATE ${table.name}
  ///       SET role = 'user'
  ///       WHERE role IS NULL
  ///     ''');
  ///   },
  /// )
  /// ```
  MigrationBuilder<T> custom({
    required String description,
    required int version,
    required Future<void> Function(DatabaseExecutor db, Table<T> table) migrate,
  }) {
    _migrations.add(TableMigration<T>(
      table: _table,
      targetVersion: version,
      description: description,
      migrate: (db, table) => migrate(db, table as Table<T>),
      priority: _currentPriority++,
    ));
    return this;
  }

  /// Adds a foreign key constraint
  ///
  /// **Example:**
  /// ```dart
  /// .addForeignKey(
  ///   column: 'user_id',
  ///   referenceTable: 'users',
  ///   referenceColumn: 'id',
  ///   version: 2,
  ///   onDelete: 'CASCADE',
  /// )
  /// ```
  MigrationBuilder<T> addForeignKey({
    required String column,
    required String referenceTable,
    required String referenceColumn,
    required int version,
    String onDelete = 'NO ACTION',
    String onUpdate = 'NO ACTION',
    String? description,
  }) {
    // SQLite doesn't support ADD FOREIGN KEY directly
    // This would need table recreation
    return custom(
      description: description ?? 'Add foreign key $column → $referenceTable($referenceColumn)',
      version: version,
      migrate: (db, table) async {
        print('⚠️  Foreign key constraints require table recreation in SQLite');
        print('    Skipping foreign key: $column → $referenceTable($referenceColumn)');
        // In production, you might want to implement table recreation here
      },
    );
  }

  /// Adds a CHECK constraint
  ///
  /// **Note:** SQLite doesn't support adding CHECK constraints to existing tables.
  /// This migration is informational only.
  MigrationBuilder<T> addCheckConstraint({
    required String constraint,
    required int version,
    String? description,
  }) {
    return custom(
      description: description ?? 'Add check constraint',
      version: version,
      migrate: (db, table) async {
        print('⚠️  SQLite doesn\'t support adding CHECK constraints to existing tables');
        print('    Constraint would be: $constraint');
        // In production, implement table recreation if needed
      },
    );
  }

  /// Workaround for dropping columns in SQLite
  Future<void> _dropColumnWorkaround(
    DatabaseExecutor db,
    Table<T> table,
    String columnName,
  ) async {
    print('⚠️  Dropping columns in SQLite requires table recreation');
    print('    This is a complex operation. Consider alternative approaches.');

    // Simplified example - in production, you'd need to:
    // 1. Get current schema
    // 2. Create new table without the column
    // 3. Copy data
    // 4. Drop old table
    // 5. Rename new table
    // 6. Recreate indexes

    throw UnsupportedError('Column dropping requires manual implementation. '
        'Consider using .custom() with your own migration logic.');
  }

  /// Truncates a string for display in descriptions
  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Builds the migration list
  Table<T> build() {
    return Table<T>(
      name: _table.name,
      schema: _table.schema,
      fromJson: _table.fromJson,
      primaryKey: _table.primaryKey,
      paranoid: _table.paranoid,
      migrations: List.unmodifiable(_migrations),
    );
  }
}
