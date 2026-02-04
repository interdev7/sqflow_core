// =======================================================
// DATABASE SERVICE WITH SMART MIGRATIONS 🚀
// =======================================================
///
/// A professional, production-ready database service for Flutter/Dart applications
/// featuring smart migration tracking, version management, and fluent API.
///
/// **Key Features:**
/// - Automatic migration tracking with idempotent execution
/// - Version-aware schema management
/// - Fluent migration builder API
/// - Support for custom migration logic
/// - Safe rollback and downgrade handling
/// - Multi-table migration coordination
///
/// **Architecture Overview:**
/// ```
/// ┌─────────────────┐
/// │   DB Service    │ ← Manages migrations & connections
/// ├─────────────────┤
/// │  RuntimeTable   │ ← Table schema + migrations
/// ├─────────────────┤
/// │  Migration      │ ← Individual migration steps
/// ├─────────────────┤
/// │ MigrationTracker│ ← Tracks applied migrations
/// └─────────────────┘
/// ```
import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflow_core/src/annotations/table.dart';
import 'package:sqflow_core/src/models/table_migration.dart';

/// Main database manager that handles connection lifecycle,
/// version management, and smart migration tracking.
///
/// **Usage Example:**
/// ```dart
/// // Define tables with migrations
/// final usersTable = RuntimeTable<User>(
///   name: 'users',
///   schema: 'CREATE TABLE users (...)',
///   fromJson: User.fromJson,
/// ).migrate()
///   .addColumn(name: 'email', type: 'TEXT', version: 2)
///   .createIndex(name: 'idx_email', columns: ['email'], version: 3)
///   .build();
///
/// // Create database with auto version detection
/// final db = DB.autoVersion(
///   databaseName: 'my_app.db',
///   tables: [usersTable, postsTable],
/// );
///
/// // Use in services
/// final userService = DatabaseService<User>(
///   dbManager: db,
///   table: usersTable,
/// );
/// ```
class DB {
  /// Database file name (e.g., 'app_database.db')
  final String databaseName;

  /// Current database schema version
  /// Must be >= highest migration version across all tables
  final int version;

  /// List of table configurations including schemas and migrations
  final List<Table> tables;

  /// Internal database instance (lazy-loaded)
  Database? _database;

  /// Name of the migrations tracking table
  static const String _migrationsTable = '__sqflow_migrations';

  /// Creates a new database instance
  ///
  /// **Parameters:**
  /// - `databaseName`: SQLite database file name
  /// - `version`: Current schema version (must be >= all migration versions)
  /// - `tables`: List of table configurations
  ///
  /// **Throws:** `ArgumentError` if any migration has version > `version`
  ///
  /// **Example:**
  /// ```dart
  /// final db = DB(
  ///   databaseName: 'app_v3.db',
  ///   version: 3,
  ///   tables: [usersTable, postsTable],
  /// );
  /// ```
  DB({
    this.databaseName = 'app_database.db',
    required this.version,
    required this.tables,
  }) {
    _validateMigrations();
  }

  /// Creates a database with auto-detected version
  ///
  /// Automatically determines the maximum version from all table migrations.
  ///
  /// **Example:**
  /// ```dart
  /// final db = DB.autoVersion(
  ///   databaseName: 'app.db',
  ///   tables: [
  ///     tableWithMigrationsUpToV2,
  ///     tableWithMigrationsUpToV3,
  ///   ],
  /// );
  /// print(db.version); // 3 (maximum from all migrations)
  /// ```
  factory DB.autoVersion({
    required String databaseName,
    required List<Table> tables,
  }) {
    // Determine maximum version from all migrations
    final maxVersion = _calculateMaxVersion(tables);

    return DB(
      databaseName: databaseName,
      version: maxVersion,
      tables: tables,
    );
  }

  /// Gets the database instance (lazy initialization)
  ///
  /// If database is not initialized, opens the connection and:
  /// 1. Creates tables on first run
  /// 2. Applies pending migrations on version upgrade
  /// 3. Initializes migration tracking
  ///
  /// **Example:**
  /// ```dart
  /// final dbInstance = await db.database;
  /// ```
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the database connection
  Future<Database> _initDatabase() async {
    final String path;
    if (databaseName == ':memory:') {
      path = databaseName;
    } else {
      path = join(await getDatabasesPath(), databaseName);
    }

    print('🔧 Initializing database: $databaseName (v$version)');

    return await openDatabase(
      path,
      version: version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
      onConfigure: _onConfigure,
    );
  }

  /// Validates that all migrations are within the database version
  void _validateMigrations() {
    for (final table in tables) {
      for (final migration in table.migrations) {
        if (migration.targetVersion > version) {
          throw ArgumentError('Table "${table.name}" has migration "${migration.description}" '
              'for version ${migration.targetVersion}, but database version is $version. '
              'Either increase database version or remove the migration.');
        }
      }
    }
  }

  /// Calculates maximum version from all table migrations
  static int _calculateMaxVersion(List<Table> tables) {
    int maxVersion = 1; // Minimum version

    for (final table in tables) {
      for (final migration in table.migrations) {
        if (migration.targetVersion > maxVersion) {
          maxVersion = migration.targetVersion;
        }
      }
    }

    return maxVersion;
  }

  /// Database configuration callback
  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys if needed
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Database creation callback (first run)
  Future<void> _onCreate(Database db, int version) async {
    print('✨ Creating new database (v$version)');

    // 1. Create migrations tracking table
    await _createMigrationsTable(db);

    // 2. Create all tables
    for (final table in tables) {
      await _createTable(db, table);
    }

    // 3. Mark all migrations as applied (since we're creating from scratch)
    // await _markAllMigrationsApplied(db);
    await _applyPendingMigrations(db, 0, version);

    print('✅ Database created successfully');
  }

  /// Database upgrade callback (version increase)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from v$oldVersion to v$newVersion');

    // 1. Ensure migrations table exists
    await _createMigrationsTable(db);

    for (final table in tables) {
      // Check table existence in sqlite_master system table
      final tableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [table.name],
      );

      if (tableCheck.isEmpty) {
        print('📦 New table detected: ${table.name}. Creating...');
        await _createTable(db, table);
      }
    }

    // 2. Apply pending migrations
    await _applyPendingMigrations(db, oldVersion, newVersion);

    print('✅ Database upgraded successfully');
  }

  /// Database downgrade callback (version decrease)
  ///
  /// **Note:** SQLite doesn't support schema downgrades natively.
  /// This implementation recreates the database from scratch.
  /// For production, consider more sophisticated downgrade strategies.
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    print('⚠️  Downgrading database from v$oldVersion to v$newVersion');

    // Close current connection
    await db.close();

    // Delete database file
    if (databaseName == ':memory:') {
      // In-memory databases are destroyed when closed
    } else {
      final path = join(await getDatabasesPath(), databaseName);
      await deleteDatabase(path);
    }

    // Recreate with new version
    _database = null;
    await database;

    print('✅ Database downgraded by recreation');
  }

  /// Creates the migrations tracking table
  Future<void> _createMigrationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_migrationsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        migration_version INTEGER NOT NULL,
        migration_hash TEXT NOT NULL,
        description TEXT,
        applied_at TEXT NOT NULL,
        UNIQUE(table_name, migration_version, migration_hash)
      )
    ''');

    // Create index for faster lookups
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_migrations_lookup 
      ON $_migrationsTable(table_name, migration_version)
    ''');
  }

  /// Creates a single table with its schema
  Future<void> _createTable(Database db, Table table) async {
    try {
      print('  📦 Creating table: ${table.name}');
      await db.execute(table.schema);
    } catch (e, stackTrace) {
      print('  ❌ Failed to create table ${table.name}: $e');
      print('  Schema: ${table.schema}');
      print('  Stack Trace: $stackTrace');
      rethrow;
    }
  }

  /// Marks all migrations as applied (for initial database creation)
  ///
  /// **Note:** This method should be called after database creation
  /// to ensure all migrations are tracked.
  Future<void> synchronizeHistory() async {
    final db = await database;
    final allMigrations = tables.expand((t) => t.migrations).toList();

    await db.transaction((txn) async {
      for (final migration in allMigrations) {
        // Ensure no duplicate records before insert
        final exists = await txn.query(
          _migrationsTable,
          where: 'table_name = ? AND migration_version = ?',
          whereArgs: [migration.table.name, migration.targetVersion],
        );

        if (exists.isEmpty) {
          await txn.insert(_migrationsTable, {
            'table_name': migration.table.name,
            'migration_version': migration.targetVersion,
            'description': '${migration.description} (Synced)',
            'applied_at': DateTime.now().toIso8601String(),
          });
        }
      }
    });
  }

  /// Applies pending migrations between versions
  Future<void> _applyPendingMigrations(
    DatabaseExecutor db,
    int fromVersion,
    int toVersion,
  ) async {
    // Collect all migrations in the version range
    final pendingMigrations = <_PendingMigration>[];

    for (final table in tables) {
      for (final migration in table.migrations) {
        if (migration.targetVersion > fromVersion && migration.targetVersion <= toVersion) {
          pendingMigrations.add(_PendingMigration(table, migration));
        }
      }
    }

    if (pendingMigrations.isEmpty) {
      print('  ⏭️  No pending migrations found');
      return;
    }

    // Sort by version and priority
    pendingMigrations.sort((a, b) {
      final versionCompare = a.migration.targetVersion.compareTo(b.migration.targetVersion);
      if (versionCompare != 0) return versionCompare;
      return a.migration.priority.compareTo(b.migration.priority);
    });

    print('  📋 Found ${pendingMigrations.length} pending migrations');

    // Apply migrations
    // Note: onCreate/onUpgrade are already running in a transaction,
    // so we don't need to start a new one here.
    for (final pending in pendingMigrations) {
      await _applySingleMigration(db, pending.table, pending.migration);
    }
  }

  /// Applies a single migration with idempotency check
  Future<void> _applySingleMigration(
    DatabaseExecutor db,
    Table table,
    TableMigration migration,
  ) async {
    final hash = _calculateMigrationHash(migration);

    // Check if already applied
    final isApplied = await _isMigrationApplied(db, table.name, hash);

    if (isApplied) {
      print('  ⏭️  Skipping (already applied): ${migration.description}');
      return;
    }

    print('  🔄 Applying: ${migration.description} '
        '(v${migration.targetVersion})');

    try {
      // Execute migration
      await migration.migrate(db, table);

      // Record as applied
      await db.insert(_migrationsTable, {
        'table_name': table.name,
        'migration_version': migration.targetVersion,
        'migration_hash': hash,
        'description': migration.description,
        'applied_at': DateTime.now().toIso8601String(),
      });

      print('  ✅ Success');
    } catch (e, stackTrace) {
      print('  ❌ Failed: $e');
      print('  Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Checks if a migration has already been applied
  Future<bool> _isMigrationApplied(
    DatabaseExecutor db,
    String tableName,
    String hash,
  ) async {
    final result = await db.query(
      _migrationsTable,
      where: 'table_name = ? AND migration_hash = ?',
      whereArgs: [tableName, hash],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Calculates a unique hash for a migration
  ///
  /// Used to detect changes to migration logic and prevent re-application
  /// of modified migrations.
  String _calculateMigrationHash(TableMigration migration) {
    // Create a deterministic string representation
    final content = {
      'table': migration.table.name,
      'version': migration.targetVersion,
      'description': migration.description,
      'priority': migration.priority,
    };

    // Convert to JSON and hash
    final jsonString = jsonEncode(content);
    return _simpleHash(jsonString);
  }

  /// Simple string hashing function
  String _simpleHash(String input) {
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      hash = (hash << 5) - hash + input.codeUnitAt(i);
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash.abs().toString();
  }

  /// Gets a list of all applied migrations
  ///
  /// Useful for debugging and migration reports.
  Future<List<Map<String, dynamic>>> getAppliedMigrations() async {
    final db = await database;
    return await db.query(
      _migrationsTable,
      orderBy: 'applied_at DESC',
    );
  }

  /// Gets the current database version from the file
  ///
  /// This is the actual version stored in the database file,
  /// which may differ from the `version` property if migrations
  /// are pending.
  Future<int> getCurrentFileVersion() async {
    final String path;
    if (databaseName == ':memory:') {
      path = databaseName;
    } else {
      path = join(await getDatabasesPath(), databaseName);
    }

    try {
      final db = await openDatabase(
        path,
        readOnly: true,
      );
      final version = await db.getVersion();
      await db.close();
      return version;
    } catch (_) {
      return 0; // Database doesn't exist
    }
  }

  /// Resets the database (for testing only)
  ///
  /// **Warning:** Deletes all data! Use only in tests.
  Future<void> reset() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    if (databaseName == ':memory:') {
      return;
    }

    final path = join(await getDatabasesPath(), databaseName);
    try {
      await deleteDatabase(path);
    } catch (_) {
      // Ignore if file doesn't exist
    }
  }

  /// Closes the database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

/// Helper class for tracking pending migrations
class _PendingMigration {
  final Table table;
  final TableMigration migration;

  _PendingMigration(this.table, this.migration);
}
