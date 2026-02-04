// =======================================================
// SORT BUILDER 📊
// =======================================================
///
/// Fluent builder for SQL ORDER BY clauses. Supports ASC/DESC ordering by columns.
/// Validates column names. Use in [DatabaseService.readAll] for sorted results.
///
/// **Key Features:**
/// - Chainable: Multiple columns (e.g., name ASC, age DESC).
/// - Joins with comma (e.g., 'name ASC, age DESC').
/// - Column validation to prevent errors.
class SortBuilder {
  final List<String> _orders = [];
  static final RegExp _columnRegExp = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

  void _validate(String column) {
    if (!_columnRegExp.hasMatch(column)) {
      throw ArgumentError('Invalid column name: $column. '
          'Column name must contain only letters, numbers and underscores, and start with a letter or underscore.');
    }
  }

  /// Adds ascending order: `column ASC`.
  ///
  /// **Example:**
  /// ```dart
  /// SortBuilder().asc('name')
  /// ```
  SortBuilder asc(String column) {
    _validate(column);
    _orders.add('$column ASC');
    return this;
  }

  /// Adds descending order: `column DESC`.
  ///
  /// **Example:**
  /// ```dart
  /// SortBuilder().desc('created_at') // Newest first
  /// ```
  SortBuilder desc(String column) {
    _validate(column);
    _orders.add('$column DESC');
    return this;
  }

  /// Builds the full ORDER BY string (or null if empty).
  /// Use with `db.query(orderBy: build())`.
  String? build() => _orders.isEmpty ? null : _orders.join(', ');

  /// Creates a copy of this SortBuilder
  SortBuilder copy() {
    final copy = SortBuilder();
    copy._orders.addAll(_orders);
    return copy;
  }
}
