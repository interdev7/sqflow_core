# Changelog

All notable changes for the sqflow_core package.

## 1.0.0 — 2026-01-23

- First public release.
- CRUD service for SQLite with soft delete support.
- WhereBuilder for complex filters (AND/OR groups, inList, like, dateOnlyBetween, isNull/isTrue).
- Batch operations: insertBatchAsync, updateBatchAsync, deleteBatchAsync, restoreBatchAsync.
- SortBuilder for sorting by multiple fields.
- Table schema and index management (IndexProps).
- Tests based on sqflite_common_ffi for in-memory environment.
