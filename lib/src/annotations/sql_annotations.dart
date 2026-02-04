import 'data_types.dart';

/// Strategy for naming database columns.
enum ColumnNamingStrategy {
  /// Use snake_case (e.g., `firstName` -> `first_name`).
  snakeCase,

  /// Use camelCase (e.g., `firstName` -> `firstName`).
  camelCase,

  /// Use PascalCase (e.g., `firstName` -> `FirstName`).
  pascalCase,
}

/// Base class for all column definitions.
///
/// Contains properties common to any table column,
/// such as type, nullability, uniqueness, defaults,
/// and value constraints.
abstract class ColumnBase {
  /// Database data type of the column.
  final DataTypes type;

  /// Whether the column allows NULL values.
  ///
  /// Defaults to `false`.
  final bool nullable;

  /// Whether the column enforces uniqueness.
  ///
  /// Adds a UNIQUE constraint.
  final bool unique;

  /// Default value used when no value is provided.
  final dynamic defaultValue;

  /// Optional value constraint.
  ///
  /// Can be used to restrict allowed values.
  final CHECK? check;

  const ColumnBase({
    required this.type,
    this.nullable = false,
    this.unique = false,
    this.defaultValue,
    this.check,
  });
}

/// Standard column definition.
///
/// Used for most non-key fields.
class Column extends ColumnBase {
  /// Maximum length of the column.
  ///
  /// Typically used for string-based types.
  final int? length;

  /// Total number of digits.
  ///
  /// Used for numeric and decimal types.
  final int? precision;

  /// Number of digits after the decimal point.
  final int? scale;

  const Column({
    required super.type,
    super.nullable,
    super.unique,
    super.defaultValue,
    super.check,
    this.length,
    this.precision,
    this.scale,
  });
}

/// Primary key column.
///
/// Intended for identifier fields.
class ID extends ColumnBase {
  /// Whether the value is generated automatically.
  ///
  /// For example, auto-incrementing integers.
  final bool autoIncrement;

  const ID({
    required super.type,
    this.autoIncrement = false,
    super.unique = true,
  }) : super(nullable: false);
}

/// Table-level schema configuration.
class Schema {
  /// Optional explicit table name.
  ///
  /// If not provided, a default naming strategy may be used.
  final String? tableName;

  /// List of indexes defined on the table.
  final List<Index> indexes;

  /// Enables soft deletion support.
  ///
  /// When enabled, records are marked as deleted
  /// instead of being physically removed.
  final bool paranoid;

  final ColumnNamingStrategy columnNaming;

  const Schema({
    this.tableName,
    this.indexes = const [],
    this.paranoid = false,
    this.columnNaming = ColumnNamingStrategy.snakeCase,
  });
}

/// Database index definition.
class Index {
  /// Columns included in the index.
  final List<String> columns;

  /// Whether the index enforces uniqueness.
  final bool unique;

  const Index({
    required this.columns,
    this.unique = false,
  });
}

/// Value constraint definition.
///
/// Restricts column values to a predefined set.
class CHECK {
  /// Allowed values for the column.
  final List<dynamic> values;

  const CHECK(this.values);
}

/// Foreign key column.
///
/// Represents a reference to another table.
class ForeignKey extends ColumnBase {
  /// Referenced table name.
  final String referencesTable;

  /// Referenced column name.
  final String referencesColumn;

  /// Action applied when the referenced record is deleted.
  ///
  /// Examples: `CASCADE`, `SET NULL`, `RESTRICT`
  final String? onDelete;

  /// Action applied when the referenced record is updated.
  final String? onUpdate;

  const ForeignKey({
    required super.type,
    required this.referencesTable,
    required this.referencesColumn,
    super.nullable,
    this.onDelete,
    this.onUpdate,
  });
}
