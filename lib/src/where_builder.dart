// =======================================================
// WHERE BUILDER 🔍
// =======================================================

/// Internal class to store a condition with its arguments
class _Condition {
  final dynamic condition; // String or WhereBuilder
  final List<Object?> args;
  final String? column;

  _Condition(this.condition, this.args, this.column);
}

///
/// Fluent SQL WHERE clause builder with support for parameterized queries,
/// complex nested conditions, and safe column validation.
///
/// **Key Features:**
/// - Parameterized queries (? placeholders) for SQL injection protection
/// - Column name validation (alphanumeric + underscores)
/// - Nested AND/OR groups with automatic parentheses
/// - Maintains argument order exactly as conditions are added
/// - Complex condition building with raw() method escape hatch
/// - DateTime to ISO string conversion
/// - Tracks used columns for hasConditionOn() checks
///
/// **Basic Usage:**
/// ```dart
/// final where = WhereBuilder()
///   .eq('status', 'active')
///   .gt('age', 18)
///   .like('name', '%John%');
///
/// // Produces: status = ? AND age > ? AND name LIKE ?
/// // Args: ['active', 18, '%John%']
/// ```
class WhereBuilder {
  /// Stores all conditions with their arguments in the order they were added
  final List<_Condition> _conditions = [];

  /// Logical operator to join conditions (default: ' AND ')
  final String _separator;

  /// Tracks which columns have been used in conditions
  final Set<String> _usedColumns = {};

  /// Column name validation regex (letters, numbers, underscores)
  static final RegExp _columnRegExp = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

  /// Creates a new WhereBuilder instance
  ///
  /// **Parameters:**
  /// - `separator`: Logical operator to join conditions (default: ' AND ')
  ///
  /// **Example:**
  /// ```dart
  /// final where = WhereBuilder(); // Uses AND by default
  /// final orWhere = WhereBuilder(separator: ' OR ');
  /// ```
  WhereBuilder({String separator = ' AND '}) : _separator = separator;

  // =======================================================
  // VALIDATION & UTILITY METHODS
  // =======================================================

  /// Validates column name format
  ///
  /// **Throws:** ArgumentError if column name is invalid
  void _validate(String column) {
    if (!_columnRegExp.hasMatch(column)) {
      throw ArgumentError('Invalid column name: "$column". '
          'Must contain only letters, numbers, underscores, '
          'and start with a letter or underscore.');
    }
  }

  /// Prepares value for SQL insertion
  ///
  /// **Converts:**
  /// - bool → 1/0
  /// - DateTime → ISO 8601 string
  Object? _prepareValue(Object? value) {
    if (value is bool) return value ? 1 : 0;
    if (value is DateTime) return value.toIso8601String();
    return value;
  }

  /// Extracts column names from raw SQL for tracking
  void _extractColumnsFromRaw(String condition) {
    final columnRegex = RegExp(
      r'\b([a-zA-Z_][a-zA-Z0-9_]*)\s*(?:=|!=|>|<|>=|<=|LIKE|NOT\s+LIKE|IS|IS\s+NOT|IN|NOT\s+IN|BETWEEN|REGEXP)\b',
      caseSensitive: false,
    );

    final matches = columnRegex.allMatches(condition);
    for (final match in matches) {
      final column = match.group(1)!;
      if (_columnRegExp.hasMatch(column)) {
        _usedColumns.add(column);
      }
    }
  }

  /// Adds a simple condition with arguments
  void _addCondition(String condition, List<Object?> args, String? column) {
    _conditions.add(_Condition(condition, args, column));
    if (column != null) {
      _usedColumns.add(column);
    }
  }

  /// Adds a nested WhereBuilder as a condition
  void _addBuilder(WhereBuilder builder, String? column) {
    _conditions.add(_Condition(builder, [], column));
    _usedColumns.addAll(builder._usedColumns);
  }

  // =======================================================
  // BASIC COMPARISON OPERATORS (=, !=, >, <, >=, <=)
  // =======================================================

  /// Adds equality condition: `column = ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.eq('status', 'active');
  /// // Produces: status = ?
  /// // Args: ['active']
  /// ```
  WhereBuilder eq(String column, Object? value) {
    _validate(column);
    if (value == null) return this;
    _addCondition('$column = ?', [_prepareValue(value)], column);
    return this;
  }

  /// Adds inequality condition: `column != ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.ne('status', 'inactive');
  /// // Produces: status != ?
  /// // Args: ['inactive']
  /// ```
  WhereBuilder ne(String column, Object? value) {
    _validate(column);
    if (value == null) return this;
    _addCondition('$column != ?', [_prepareValue(value)], column);
    return this;
  }

  /// Adds greater-than condition: `column > ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.gt('age', 18);
  /// // Produces: age > ?
  /// // Args: [18]
  /// ```
  WhereBuilder gt(String column, Object value) {
    _validate(column);
    _addCondition('$column > ?', [_prepareValue(value)], column);
    return this;
  }

  /// Adds greater-than-or-equal condition: `column >= ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.gte('score', 60);
  /// // Produces: score >= ?
  /// // Args: [60]
  /// ```
  WhereBuilder gte(String column, Object value) {
    _validate(column);
    _addCondition('$column >= ?', [_prepareValue(value)], column);
    return this;
  }

  /// Adds less-than condition: `column < ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.lt('age', 65);
  /// // Produces: age < ?
  /// // Args: [65]
  /// ```
  WhereBuilder lt(String column, Object value) {
    _validate(column);
    _addCondition('$column < ?', [_prepareValue(value)], column);
    return this;
  }

  /// Adds less-than-or-equal condition: `column <= ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.lte('quantity', 100);
  /// // Produces: quantity <= ?
  /// // Args: [100]
  /// ```
  WhereBuilder lte(String column, Object value) {
    _validate(column);
    _addCondition('$column <= ?', [_prepareValue(value)], column);
    return this;
  }

  // =======================================================
  // PATTERN MATCHING (LIKE, NOT LIKE, ILIKE)
  // =======================================================

  /// Adds case-sensitive LIKE condition: `column LIKE ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.like('name', '%John%');
  /// // Produces: name LIKE ?
  /// // Args: ['%John%']
  /// ```
  WhereBuilder like(String column, String pattern) {
    _validate(column);
    _addCondition('$column LIKE ?', [pattern], column);
    return this;
  }

  /// Adds NOT LIKE condition: `column NOT LIKE ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.notLike('email', '%spam.com');
  /// // Produces: email NOT LIKE ?
  /// // Args: ['%spam.com']
  /// ```
  WhereBuilder notLike(String column, String pattern) {
    _validate(column);
    _addCondition('$column NOT LIKE ?', [pattern], column);
    return this;
  }

  /// Adds case-insensitive LIKE condition: `LOWER(column) LIKE LOWER(?)`
  ///
  /// **Example:**
  /// ```dart
  /// where.ilike('name', '%john%');
  /// // Produces: LOWER(name) LIKE LOWER(?)
  /// // Args: ['%john%']
  /// ```
  WhereBuilder ilike(String column, String pattern) {
    _validate(column);
    _addCondition('LOWER($column) LIKE LOWER(?)', [pattern], column);
    return this;
  }

  /// Adds case-insensitive NOT LIKE condition: `LOWER(column) NOT LIKE LOWER(?)`
  ///
  /// **Example:**
  /// ```dart
  /// where.notIlike('name', '%test%');
  /// // Produces: LOWER(name) NOT LIKE LOWER(?)
  /// // Args: ['%test%']
  /// ```
  WhereBuilder notIlike(String column, String pattern) {
    _validate(column);
    _addCondition('LOWER($column) NOT LIKE LOWER(?)', [pattern], column);
    return this;
  }

  /// Adds REGEXP condition: `column REGEXP ?` (SQLite)
  ///
  /// **Example:**
  /// ```dart
  /// where.regexp('phone', '^[0-9]{10}\$');
  /// // Produces: phone REGEXP ?
  /// // Args: ['^[0-9]{10}\$']
  /// ```
  WhereBuilder regexp(String column, String pattern) {
    _validate(column);
    _addCondition('$column REGEXP ?', [pattern], column);
    return this;
  }

  // =======================================================
  // RANGE & SET OPERATIONS (BETWEEN, IN, NOT IN)
  // =======================================================

  /// Adds range condition: `column BETWEEN ? AND ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.between('age', 18, 65);
  /// // Produces: age BETWEEN ? AND ?
  /// // Args: [18, 65]
  /// ```
  WhereBuilder between(String column, Object from, Object to) {
    _validate(column);
    _addCondition(
      '$column BETWEEN ? AND ?',
      [_prepareValue(from), _prepareValue(to)],
      column,
    );
    return this;
  }

  /// Adds IN condition: `column IN (?, ?, ...)`
  ///
  /// **Example:**
  /// ```dart
  /// where.inList('status', ['active', 'pending']);
  /// // Produces: status IN (?, ?)
  /// // Args: ['active', 'pending']
  /// ```
  WhereBuilder inList(String column, List<Object?> values) {
    _validate(column);
    if (values.isEmpty) {
      _addCondition('1 = 0', [], column); // Always false
      return this;
    }
    final preparedValues = values.map(_prepareValue).toList();
    final placeholders = List.filled(preparedValues.length, '?').join(', ');
    _addCondition('$column IN ($placeholders)', preparedValues, column);
    return this;
  }

  /// Adds NOT IN condition: `column NOT IN (?, ?, ...)`
  ///
  /// **Example:**
  /// ```dart
  /// where.notInList('role', ['admin', 'superuser']);
  /// // Produces: role NOT IN (?, ?)
  /// // Args: ['admin', 'superuser']
  /// ```
  WhereBuilder notInList(String column, List<Object?> values) {
    _validate(column);
    if (values.isEmpty) return this; // No restriction
    final preparedValues = values.map(_prepareValue).toList();
    final placeholders = List.filled(preparedValues.length, '?').join(', ');
    _addCondition('$column NOT IN ($placeholders)', preparedValues, column);
    return this;
  }

  // =======================================================
  // NULL CHECKS (IS NULL, IS NOT NULL)
  // =======================================================

  /// Adds IS NULL condition: `column IS NULL`
  ///
  /// **Example:**
  /// ```dart
  /// where.isNull('deleted_at');
  /// // Produces: deleted_at IS NULL
  /// ```
  WhereBuilder isNull(String column) {
    _validate(column);
    _addCondition('$column IS NULL', [], column);
    return this;
  }

  /// Adds IS NOT NULL condition: `column IS NOT NULL`
  ///
  /// **Example:**
  /// ```dart
  /// where.isNotNull('email');
  /// // Produces: email IS NOT NULL
  /// ```
  WhereBuilder isNotNull(String column) {
    _validate(column);
    _addCondition('$column IS NOT NULL', [], column);
    return this;
  }

  // =======================================================
  // BOOLEAN OPERATIONS (TRUE, FALSE)
  // =======================================================

  /// Adds true condition: `column = 1` (boolean stored as 1/0)
  ///
  /// **Example:**
  /// ```dart
  /// where.isTrue('is_active');
  /// // Produces: is_active = 1
  /// ```
  WhereBuilder isTrue(String column) {
    _validate(column);
    _addCondition('$column = 1', [], column);
    return this;
  }

  /// Adds false condition: `column = 0` (boolean stored as 1/0)
  ///
  /// **Example:**
  /// ```dart
  /// where.isFalse('is_deleted');
  /// // Produces: is_deleted = 0
  /// ```
  WhereBuilder isFalse(String column) {
    _validate(column);
    _addCondition('$column = 0', [], column);
    return this;
  }

  // =======================================================
  // LOGICAL GROUPS (AND/OR NESTING)
  // =======================================================

  /// Creates an AND group with nested conditions
  ///
  /// **Arguments are collected in the order they appear in the group.**
  ///
  /// **Example:**
  /// ```dart
  /// where
  ///   .eq('country', 'Bulgaria')
  ///   .andGroup((wg) {
  ///     wg.gt('age', 18).lt('age', 65);
  ///   })
  ///   .eq('is_verified', 1);
  ///
  /// // Produces: country = ? AND (age > ? AND age < ?) AND is_verified = ?
  /// // Args: ['Bulgaria', 18, 65, 1] ← Correct order!
  /// ```
  WhereBuilder andGroup(void Function(WhereBuilder) builder) {
    final group = WhereBuilder(separator: ' AND ');
    builder(group);

    if (group._conditions.isEmpty) return this;

    _addBuilder(group, null);
    return this;
  }

  /// Creates an OR group with nested conditions
  ///
  /// **Example:**
  /// ```dart
  /// where
  ///   .eq('is_active', 1)
  ///   .orGroup((wg) {
  ///     wg.eq('city', 'Sofia').eq('city', 'Plovdiv');
  ///   });
  ///
  /// // Produces: is_active = ? AND (city = ? OR city = ?)
  /// // Args: [1, 'Sofia', 'Plovdiv'] ← Correct order!
  /// ```
  WhereBuilder orGroup(void Function(WhereBuilder) builder) {
    final group = WhereBuilder(separator: ' OR ');
    builder(group);

    if (group._conditions.isEmpty) return this;

    _addBuilder(group, null);
    return this;
  }

  // =======================================================
  // RAW SQL CONDITIONS (USE WITH CAUTION)
  // =======================================================

  /// Adds raw SQL condition (escape hatch for complex cases)
  ///
  /// **Warning:** Use only when necessary. Validate inputs carefully.
  /// Placeholder count must match arguments length.
  ///
  /// **Example:**
  /// ```dart
  /// where.raw('LENGTH(name) > ?', [3]);
  /// // Produces: LENGTH(name) > ?
  /// // Args: [3]
  /// ```
  WhereBuilder raw(String condition, [List<Object?>? args]) {
    if (condition.isEmpty) return this;

    final questionCount = '?'.allMatches(condition).length;
    if (args != null && args.length != questionCount) {
      throw ArgumentError('Placeholder/argument mismatch in raw condition. '
          'Expected $questionCount arguments, got ${args.length}. '
          'Condition: $condition');
    }

    final preparedArgs = args?.map(_prepareValue).toList() ?? [];
    _addCondition(condition, preparedArgs, null);
    _extractColumnsFromRaw(condition);

    return this;
  }

  // =======================================================
  // DATE/TIME SPECIALIZED METHODS
  // =======================================================

  /// Adds date-only equality (ignores time part): `DATE(column) = ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.dateOnlyEq('created_at', DateTime(2024, 1, 15));
  /// // Produces: DATE(created_at) = ?
  /// // Args: ['2024-01-15']
  /// ```
  WhereBuilder dateOnlyEq(String column, DateTime date) {
    _validate(column);
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    _addCondition('DATE($column) = ?', [dateStr], column);
    return this;
  }

  /// Adds date-only greater-than: `DATE(column) > ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.dateOnlyGt('birth_date', DateTime(2000, 1, 1));
  /// // Produces: DATE(birth_date) > ?
  /// // Args: ['2000-01-01']
  /// ```
  WhereBuilder dateOnlyGt(String column, DateTime date) {
    _validate(column);
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    _addCondition('DATE($column) > ?', [dateStr], column);
    return this;
  }

  /// Adds date-only less-than: `DATE(column) < ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.dateOnlyLt('expiry_date', DateTime(2025, 12, 31));
  /// // Produces: DATE(expiry_date) < ?
  /// // Args: ['2025-12-31']
  /// ```
  WhereBuilder dateOnlyLt(String column, DateTime date) {
    _validate(column);
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    _addCondition('DATE($column) < ?', [dateStr], column);
    return this;
  }

  /// Adds date-only between range: `DATE(column) BETWEEN ? AND ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.dateOnlyBetween('created_at',
  ///   DateTime(2024, 1, 1),
  ///   DateTime(2024, 12, 31)
  /// );
  /// // Produces: DATE(created_at) BETWEEN ? AND ?
  /// // Args: ['2024-01-01', '2024-12-31']
  /// ```
  WhereBuilder dateOnlyBetween(String column, DateTime from, DateTime to) {
    _validate(column);
    final fromStr = '${from.year}-${from.month.toString().padLeft(2, '0')}-'
        '${from.day.toString().padLeft(2, '0')}';
    final toStr = '${to.year}-${to.month.toString().padLeft(2, '0')}-'
        '${to.day.toString().padLeft(2, '0')}';
    _addCondition('DATE($column) BETWEEN ? AND ?', [fromStr, toStr], column);
    return this;
  }

  /// Adds time-only equality (ignores date part): `TIME(column) = ?`
  ///
  /// **Example:**
  /// ```dart
  /// where.timeOnlyEq('created_at', DateTime(2024, 1, 1, 14, 30));
  /// // Produces: TIME(created_at) = ?
  /// // Args: ['14:30:00']
  /// ```
  WhereBuilder timeOnlyEq(String column, DateTime time) {
    _validate(column);
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
    _addCondition('TIME($column) = ?', [timeStr], column);
    return this;
  }

  // =======================================================
  // BUILDER OUTPUT & UTILITIES
  // =======================================================

  /// Builds the complete WHERE clause string
  ///
  /// **Example:**
  /// ```dart
  /// final where = WhereBuilder()
  ///   .eq('status', 'active')
  ///   .gt('age', 18);
  ///
  /// print(where.build()); // "status = ? AND age > ?"
  /// ```
  String build() {
    final parts = <String>[];

    for (final condition in _conditions) {
      if (condition.condition is String) {
        parts.add(condition.condition as String);
      } else if (condition.condition is WhereBuilder) {
        final builder = condition.condition as WhereBuilder;
        final built = builder.build();
        if (built.isNotEmpty) {
          // Add parentheses only if multiple conditions in group
          parts.add(builder._conditions.length > 1 ? '($built)' : built);
        }
      }
    }

    return parts.join(_separator);
  }

  /// Gets all argument values in order for placeholders
  ///
  /// **Arguments are collected in the exact order conditions were added.**
  ///
  /// **Example:**
  /// ```dart
  /// final where = WhereBuilder()
  ///   .eq('status', 'active')
  ///   .andGroup((wg) {
  ///     wg.gt('age', 18).lt('age', 65);
  ///   });
  ///
  /// print(where.args); // ['active', 18, 65]
  /// ```
  List<Object?> get args {
    final allArgs = <Object?>[];

    for (final condition in _conditions) {
      if (condition.condition is String) {
        // For string conditions, add their arguments
        allArgs.addAll(condition.args);
      } else if (condition.condition is WhereBuilder) {
        // For nested builders, recursively collect arguments
        final builder = condition.condition as WhereBuilder;
        allArgs.addAll(builder.args);
      }
    }

    return List.unmodifiable(allArgs);
  }

  /// Creates a deep copy of this WhereBuilder
  ///
  /// **Example:**
  /// ```dart
  /// final original = WhereBuilder().eq('status', 'active');
  /// final copy = original.copy();
  /// copy.eq('is_verified', 1);
  ///
  /// // original still has only 'status' condition
  /// // copy has both 'status' and 'is_verified' conditions
  /// ```
  WhereBuilder copy() {
    final copy = WhereBuilder(separator: _separator);

    for (final condition in _conditions) {
      if (condition.condition is String) {
        copy._addCondition(
          condition.condition as String,
          List.from(condition.args),
          condition.column,
        );
      } else if (condition.condition is WhereBuilder) {
        final builder = condition.condition as WhereBuilder;
        copy._addBuilder(builder.copy(), condition.column);
      }
    }

    return copy;
  }

  /// Creates a deep copy of this WhereBuilder (alias for [copy])
  WhereBuilder clone() => copy();

  /// Checks if a column is referenced in any condition
  ///
  /// **Example:**
  /// ```dart
  /// final where = WhereBuilder()
  ///   .eq('status', 'active')
  ///   .gt('age', 18);
  ///
  /// print(where.hasConditionOn('status')); // true
  /// print(where.hasConditionOn('email'));  // false
  /// ```
  bool hasConditionOn(String column) {
    return _usedColumns.contains(column);
  }

  /// Returns read-only set of all columns used in conditions
  ///
  /// **Example:**
  /// ```dart
  /// final columns = where.usedColumns;
  /// print(columns); // {'status', 'age'}
  /// ```
  Set<String> get usedColumns => Set.unmodifiable(_usedColumns);

  /// Checks if builder has no conditions
  ///
  /// **Example:**
  /// ```dart
  /// final where = WhereBuilder();
  /// print(where.isEmpty); // true
  ///
  /// where.eq('status', 'active');
  /// print(where.isEmpty); // false
  /// ```
  bool get isEmpty => _conditions.isEmpty;

  /// Checks if builder has conditions
  bool get isNotEmpty => _conditions.isEmpty;

  // =======================================================
  // DEBUG UTILITIES
  // =======================================================

  /// Prints the structure of the builder for debugging
  ///
  /// **Example:**
  /// ```dart
  /// final where = WhereBuilder()
  ///   .eq('status', 'active')
  ///   .andGroup((wg) {
  ///     wg.gt('age', 18).lt('age', 65);
  ///   });
  ///
  /// where.debugPrint();
  /// // Output:
  /// // WhereBuilder:
  /// //   Separator: " AND "
  /// //   Conditions: 2
  /// //   Used columns: {status, age}
  /// //   Built SQL: "status = ? AND (age > ? AND age < ?)"
  /// //   Args: ['active', 18, 65]
  /// ```
  void debugPrint([String indent = '']) {
    print('${indent}WhereBuilder:');
    print('${indent}  Separator: "$_separator"');
    print('${indent}  Conditions: ${_conditions.length}');
    print('${indent}  Used columns: $_usedColumns');
    print('${indent}  Built SQL: "${build()}"');
    print('${indent}  Args: $args');

    for (var i = 0; i < _conditions.length; i++) {
      final condition = _conditions[i];
      if (condition.condition is String) {
        print('${indent}  [$i] Condition: "${condition.condition}"');
        if (condition.args.isNotEmpty) {
          print('${indent}      Args: ${condition.args}');
        }
      } else if (condition.condition is WhereBuilder) {
        print('${indent}  [$i] Nested Builder:');
        (condition.condition as WhereBuilder).debugPrint('${indent}    ');
      }
    }
  }
}

// =======================================================
// EXTENSION: WHERE BUILDER CONVENIENCE METHODS
// =======================================================

/// Extension methods for common WhereBuilder patterns
extension WhereBuilderExtensions on WhereBuilder {
  /// Adds condition only if value is not null and not empty string
  ///
  /// **Example:**
  /// ```dart
  /// where.eqIfNotNull('name', searchName);
  /// // Only adds condition if searchName is not null and not empty
  /// ```
  WhereBuilder eqIfNotNull(String column, String? value) {
    if (value != null && value.isNotEmpty) {
      return eq(column, value);
    }
    return this;
  }

  /// Adds IN condition only if list is not null and not empty
  ///
  /// **Example:**
  /// ```dart
  /// where.inListIfNotEmpty('category', selectedCategories);
  /// // Only adds condition if selectedCategories has items
  /// ```
  WhereBuilder inListIfNotEmpty(String column, List<Object?>? values) {
    if (values != null && values.isNotEmpty) {
      return inList(column, values);
    }
    return this;
  }

  /// Adds date range if both from and to are provided,
  /// or single bound if only one is provided
  ///
  /// **Example:**
  /// ```dart
  /// where.dateRangeIfProvided('created_at', startDate, endDate);
  /// ```
  WhereBuilder dateRangeIfProvided(
    String column,
    DateTime? from,
    DateTime? to,
  ) {
    if (from != null && to != null) {
      return between(column, from, to);
    } else if (from != null) {
      return gte(column, from);
    } else if (to != null) {
      return lte(column, to);
    }
    return this;
  }
}

// =======================================================
// FACTORY: COMMON WHERE BUILDER PATTERNS
// =======================================================

/// Factory functions for common WhereBuilder patterns
class WhereBuilders {
  /// Creates a WHERE clause for soft-delete aware queries
  ///
  /// **Example:**
  /// ```dart
  /// final where = WhereBuilders.softDelete(
  ///   paranoid: true,
  ///   withDeleted: false,
  ///   onlyDeleted: false,
  /// );
  /// // Produces: deleted_at IS NULL
  /// ```
  static WhereBuilder softDelete({
    required bool paranoid,
    bool withDeleted = false,
    bool onlyDeleted = false,
  }) {
    final where = WhereBuilder();

    if (paranoid) {
      if (onlyDeleted) {
        where.isNotNull('deleted_at');
      } else if (!withDeleted) {
        where.isNull('deleted_at');
      }
    }

    return where;
  }

  /// Creates WHERE clause for text search across multiple columns
  ///
  /// **Example:**
  /// ```dart
  /// final where = WhereBuilders.multiColumnSearch(
  ///   'john',
  ///   ['first_name', 'last_name', 'email'],
  ///   caseSensitive: false,
  /// );
  /// // Produces: (LOWER(first_name) LIKE LOWER(?)
  /// //            OR LOWER(last_name) LIKE LOWER(?)
  /// //            OR LOWER(email) LIKE LOWER(?))
  /// // Args: ['%john%', '%john%', '%john%']
  /// ```
  static WhereBuilder multiColumnSearch(
    String query,
    List<String> columns, {
    bool caseSensitive = false,
  }) {
    final where = WhereBuilder();

    if (query.isNotEmpty && columns.isNotEmpty) {
      where.orGroup((og) {
        final searchPattern = '%$query%';
        for (final column in columns) {
          if (caseSensitive) {
            og.like(column, searchPattern);
          } else {
            og.ilike(column, searchPattern);
          }
        }
      });
    }

    return where;
  }
}
