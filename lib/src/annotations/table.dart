import 'package:sqflow_core/src/models/migration_builder.dart';
import 'package:sqflow_core/src/models/models.dart';
import 'package:sqflow_core/src/models/table_migration.dart';

/// Represents a fully generated table schema.
///
/// This class binds together:
/// - the SQL schema definition
/// - the table name
/// - a row-to-entity mapping function
/// - table-level behavioral options
///
/// It is typically produced by code generation and
/// used internally by the runtime layer.
class Table<T extends Model> {
  /// SQL definition used to create the table.
  ///
  /// Usually contains a CREATE TABLE statement
  /// and optional index definitions.
  final String schema;

  /// Name of the database table.
  final String name;

  /// Primary key column name (default is 'id').
  final String primaryKey;

  /// List of migrations for this table
  final List<TableMigration<T>> migrations;

  /// Factory function that converts a database row
  /// into a strongly-typed entity instance.
  ///
  /// The input map represents a single row,
  /// where keys are column names.
  final T Function(Map<String, dynamic>) fromJson;

  /// Enables soft deletion behavior for the table.
  ///
  /// When enabled, records are marked as deleted
  /// instead of being physically removed.
  final bool paranoid;

  /// Creates a migration builder for this table
  ///
  /// **Example:**
  /// ```dart
  /// final migrations = table.migrate()
  ///   .addColumn(name: 'age', type: 'INTEGER', version: 2)
  ///   .createIndex(name: 'idx_email', columns: ['email'], version: 3)
  ///   .build();
  /// ```
  MigrationBuilder<T> migrate() => MigrationBuilder<T>(this);

  Table({
    required this.schema,
    required this.name,
    required this.fromJson,
    this.primaryKey = 'id',
    this.migrations = const [],
    this.paranoid = false,
  });
}
