/// MODELS 🏗️
///
/// Base model interface for CRUD operations.
/// All models must implement this to work with [DatabaseService].
///
/// **Requirements:**
/// - `id`: Unique identifier (String, int, or Object).
/// - Timestamps: Optional getters for `createdAt`, `updatedAt`, `deletedAt` (for soft delete).
/// - `toJson()`: Serializes to Map<String, dynamic> for database insertion.
abstract class Model {
  /// Unique identifier for the model instance.
  Object get id;

  /// Timestamp when the item was created (ISO8601 string in DB).
  DateTime? get createdAt;

  /// Timestamp when the item was last updated (ISO8601 string in DB).
  DateTime? get updatedAt;

  /// Timestamp when the item was soft-deleted (null if active; ISO8601 string in DB).
  DateTime? get deletedAt;

  /// Converts the model to a JSON-compatible map for database storage.
  Map<String, dynamic> toJson();
}
