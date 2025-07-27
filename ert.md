ClickHouse Release v25.2

   * Backward Incompatible Change:
       * async_load_databases is now completely enabled by default.
       * JSONCompactWithNames and JSONCompactWithNamesAndTypes no longer output "totals".
       * The format_alter_operations_with_parentheses setting is now true by default.
       * Filtering log messages using regular expressions has been removed.

   * New Feature:
       * Support for Nullable(JSON) type.
       * Support for subcolumns in DEFAULT and MATERIALIZED expressions.
       * Support for writing Parquet bloom filters.
       * The Web UI now has an interactive database navigation.
       * A new DatabaseBackup engine to instantly attach tables/databases from a backup.
       * Support for prepared statements in the Postgres wire protocol.

   * Performance Improvement:
       * Improved performance of reading the whole JSON column in Wide parts from S3.
       * Fixed unnecessary contention in parallel_hash when max_rows_in_join and max_bytes_in_join are 0.
       * Keeper improvement: disabled digest calculation when committing to in-memory storage for better performance.
       * Push down filter expression from JOIN ON when possible.

   * Bug Fix:
       * Fixed formatting of exceptions using a custom format if they appear during query interpretation.
       * Fixed type mapping for SQLite.
       * Fixed identifier resolution from parent scopes.
       * Fixed negate function monotonicity.
       * Fixed empty tuple handling in arrayIntersect.
       * Fixed a crash with the query INSERT INTO SELECT over the PostgreSQL interface on macOS.

  ClickHouse Release v25.1

   * Backward Incompatible Change:
       * JSONEachRowWithProgress will write progress whenever it happens.
       * Merge tables will unify the structure of underlying tables by using a union of their columns.
       * Parquet output format now converts Date and DateTime columns to Parquet's date/time types.
       * The obsolete MaterializedMySQL database engine has been removed.
       * CHECK TABLE queries now require a separate CHECK grant.

   * New Feature:
       * Ability to apply non-finished mutations during SELECT queries.
       * Iceberg tables partition pruning for time-related transform partition operations.
       * Support for subcolumns in MergeTree sorting key and skip indexes.
       * Support for reading HALF_FLOAT values from Apache Arrow/Parquet/ORC.
       * The system.trace_log table now contains symbolized stack traces.
       * New function generateSerialID for auto-incremental numbers.

   * Performance Improvement:
       * Optimized indexHint function to not read columns that are only used as arguments.
       * More accurate accounting for max_joined_block_size_rows setting for parallel_hash JOIN algorithm.
       * Support for predicate push down optimization on the query plan level for the MergingAggregated step.
       * Optimized RowBinary input format.

   * Bug Fix:
       * Fixed a regression that using collation locales with modifiers throws an error.
       * Fixed cannot create SEQUENTIAL node with keeper-client.
       * Fixed incorrect character counting in the position functions.
       * RESTORE operations for access entities required more permission than necessary.
       * Fixed handling of empty tuples in some input and output formats (e.g. Parquet, Arrow).