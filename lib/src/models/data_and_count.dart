/// Paginated result from [DatabaseService.readAll].
/// Contains the list of items and the total count (for UI pagination).
class DataAndCount<T> {
  /// The list of deserialized model instances (T).
  final List<T> data;

  /// Total number of matching items (considering filters/soft delete).
  final int count;

  /// Creates a new [DataAndCount] instance.
  const DataAndCount({required this.data, required this.count});
}
