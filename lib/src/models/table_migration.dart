import 'package:sqflite/sqflite.dart';
import 'package:sqflow_core/src/annotations/table.dart';
import 'package:sqflow_core/src/models/models.dart';

/// =======================================================
/// TABLE MIGRATION
/// =======================================================
///
/// Represents a single migration operation for a table.
///
/// **Properties:**
/// - `table`: The table this migration applies to
/// - `targetVersion`: Database version when this migration should be applied
/// - `description`: Human-readable description for logging
/// - `migrate`: Async function that performs the migration
/// - `priority`: Execution order within the same version (lower = earlier)
class TableMigration<T extends Model> {
  final Table<T> table;
  final int targetVersion;
  final String description;
  final Future<void> Function(DatabaseExecutor db, Table<Model> table) migrate;
  final int priority;

  TableMigration({
    required this.table,
    required this.targetVersion,
    required this.description,
    required this.migrate,
    this.priority = 0,
  });
}
