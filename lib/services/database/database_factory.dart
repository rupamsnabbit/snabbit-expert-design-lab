import 'database_interface.dart';
import 'sqlite_database.dart';

/// Factory for creating database instances
/// Provides singleton per isolate
class DatabaseFactory {
  static IDatabaseInterface? _instance;

  /// Get database instance (singleton per isolate)
  static IDatabaseInterface getInstance() {
    _instance ??= SqliteDatabase();
    return _instance!;
  }

  /// Reset instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Set custom instance (useful for testing with mocks)
  static void setInstance(IDatabaseInterface instance) {
    _instance = instance;
  }
}
