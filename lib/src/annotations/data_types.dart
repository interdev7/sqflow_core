/// Enumeration of supported database column data types.
///
/// These values describe logical column types that can later
/// be mapped to concrete database-specific representations
/// (e.g. SQLite, PostgreSQL, MySQL).
enum DataTypes {
  /// Integer numeric value.
  ///
  /// Typically used for identifiers and counters.
  INTEGER,

  /// Large integer numeric value.
  ///
  /// Intended for values exceeding standard integer range.
  BIGINT,

  /// Floating-point numeric value.
  ///
  /// Suitable for approximate decimal numbers.
  REAL,

  /// Text value of arbitrary length.
  ///
  /// Used for strings without a predefined size limit.
  TEXT,

  /// Variable-length string with optional maximum size.
  ///
  /// Commonly constrained by a length parameter.
  VARCHAR,

  /// Fixed-length character string.
  ///
  /// Often used for short codes or flags.
  CHAR,

  /// Exact numeric value with fixed precision and scale.
  ///
  /// Suitable for monetary values and precise calculations.
  DECIMAL,

  /// Boolean value.
  ///
  /// Represents true/false semantics.
  BOOLEAN,

  /// Calendar date without time component.
  ///
  /// Format and storage are database-dependent.
  DATE,

  /// Date and time value.
  ///
  /// Represents a specific moment in time.
  DATETIME,

  /// Time of day without date component.
  TIME,

  /// Binary large object.
  ///
  /// Used for storing raw binary data.
  BLOB,

  /// Structured data stored as JSON.
  ///
  /// Typically serialized as text or a native JSON type,
  /// depending on database capabilities.
  JSON,
}
