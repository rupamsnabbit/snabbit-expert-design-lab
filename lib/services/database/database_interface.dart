/// Database abstraction layer for IoT data storage
/// Allows swapping database implementations without changing business logic
abstract class IDatabaseInterface {
  /// Initialize database connection and create tables if needed
  Future<void> initialize();

  /// Generic insert operation
  /// Returns the ID of the inserted row
  Future<int> insert(String table, Map<String, dynamic> data);

  /// Generic query operation
  /// Returns list of maps representing rows
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  });

  /// Generic update operation
  /// Returns number of rows affected
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  });

  /// Generic delete operation
  /// Returns number of rows deleted
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  });

  /// Get count of rows matching criteria
  Future<int> count(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  });

  /// Execute raw SQL for complex operations
  /// Use prepared statements with arguments to prevent SQL injection
  Future<void> execute(String sql, [List<dynamic>? arguments]);

  /// Close database connection
  Future<void> close();
}

/// Table name constants
class DatabaseTables {
  static const String battery = 'iot_battery_data';
  static const String location = 'iot_location_data';
  static const String deviceState = 'iot_device_state_data';
  static const String diagnosticEvents = 'iot_diagnostic_events';
}
