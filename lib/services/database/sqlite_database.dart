import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_interface.dart';

/// SQLite implementation of IoT database
/// Handles bool↔int conversion automatically (SQLite stores bools as 0/1)
class SqliteDatabase implements IDatabaseInterface {
  Database? _db;

  /// Boolean column names that should be converted automatically
  static const _boolColumns = {'sent', 'is_mocked', 'location_services_on', 'mobile_data_on', 'processed'};

  @override
  Future<void> initialize() async {
    if (_db != null) return; // Already initialized

    try {
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, 'iot_data.db');

      _db = await openDatabase(
        path,
        version: 4,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      throw Exception('Failed to initialize IoT database: $e');
    }
  }

  /// Create tables with schema
  Future<void> _onCreate(Database db, int version) async {

    // Create battery data table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.battery} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        percentage INTEGER NOT NULL,
        collected_at INTEGER NOT NULL,
        collection_cycle_id INTEGER,
        sent INTEGER DEFAULT 0
      )
    ''');

    // Create index for battery table
    await db.execute('''
      CREATE INDEX idx_battery_user_sent_time
      ON ${DatabaseTables.battery} (user_id, sent, collected_at)
    ''');

    // Create location data table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.location} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        lat REAL NOT NULL,
        long REAL NOT NULL,
        accuracy REAL,
        alt REAL,
        alt_accuracy REAL,
        heading REAL,
        heading_accuracy REAL,
        speed REAL,
        speed_accuracy REAL,
        is_mocked INTEGER DEFAULT 0,
        collected_at INTEGER NOT NULL,
        collection_cycle_id INTEGER,
        sent INTEGER DEFAULT 0
      )
    ''');

    // Create index for location table
    await db.execute('''
      CREATE INDEX idx_location_user_sent_time
      ON ${DatabaseTables.location} (user_id, sent, collected_at)
    ''');

    // Create device state data table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.deviceState} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        location_services_on INTEGER,
        mobile_data_on INTEGER,
        network_type TEXT,
        collected_at INTEGER NOT NULL,
        collection_cycle_id INTEGER,
        sent INTEGER DEFAULT 0
      )
    ''');

    // Create index for device state table
    await db.execute('''
      CREATE INDEX idx_device_state_user_sent_time
      ON ${DatabaseTables.deviceState} (user_id, sent, collected_at)
    ''');

    // Create diagnostic events table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.diagnosticEvents} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_name TEXT NOT NULL,
        event_data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        processed INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_diagnostic_processed_time
      ON ${DatabaseTables.diagnosticEvents} (processed, created_at)
    ''');
  }

  /// Migrate database schema for version upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {

    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.deviceState} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          location_services_on INTEGER,
          mobile_data_on INTEGER,
          network_type TEXT,
          collected_at INTEGER NOT NULL,
          sent INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_device_state_user_sent_time
        ON ${DatabaseTables.deviceState} (user_id, sent, collected_at)
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.diagnosticEvents} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          event_name TEXT NOT NULL,
          event_data TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          processed INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_diagnostic_processed_time
        ON ${DatabaseTables.diagnosticEvents} (processed, created_at)
      ''');
    }

    if (oldVersion < 4) {
      // Correlation key shared by all readings collected in the same
      // background collection cycle, so the backend can group a battery
      // reading with the location/device-state readings taken alongside it
      // within a cached ping. Nullable: rows collected before this upgrade
      // stay NULL and are treated as ungroupable singletons by the backend.
      await db.execute(
        'ALTER TABLE ${DatabaseTables.battery} ADD COLUMN collection_cycle_id INTEGER',
      );
      await db.execute(
        'ALTER TABLE ${DatabaseTables.location} ADD COLUMN collection_cycle_id INTEGER',
      );
      await db.execute(
        'ALTER TABLE ${DatabaseTables.deviceState} ADD COLUMN collection_cycle_id INTEGER',
      );
    }
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> data) =>
      _withDb((db) => db.insert(table, _convertBoolsToInts(data))).onError(
          (e, st) => throw Exception('Failed to insert into $table: $e'));

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    try {
      final results = await _withDb((db) => db.query(
            table,
            where: where,
            whereArgs: whereArgs,
            orderBy: orderBy,
            limit: limit,
          ));
      return results.map(_convertIntsToBools).toList();
    } catch (e) {
      throw Exception('Failed to query $table: $e');
    }
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) =>
      _withDb((db) => db.update(
                table,
                _convertBoolsToInts(values),
                where: where,
                whereArgs: whereArgs,
              ))
          .onError(
              (e, st) => throw Exception('Failed to update into $table: $e'));

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) =>
      _withDb((db) => db.delete(
                table,
                where: where,
                whereArgs: whereArgs,
              ))
          .onError(
              (e, st) => throw Exception('Failed to delete into $table: $e'));

  @override
  Future<int> count(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    try {
      final result = await _withDb((db) => db.rawQuery(
            'SELECT COUNT(*) as count FROM $table${where != null ? " WHERE $where" : ""}',
            whereArgs,
          ));
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw Exception('Failed to count rows in $table: $e');
    }
  }

  @override
  Future<void> execute(String sql, [List<dynamic>? arguments]) =>
      _withDb((db) => db.execute(sql, arguments))
          .onError((e, st) => throw Exception('Failed to execute: $e'));

  int _activeOperations = 0;
  bool _closing = false;
  Completer<void>? _drainCompleter;

  Future<T> _withDb<T>(Future<T> Function(Database db) fn) async {
    if (_closing) throw StateError('Database is closing');
    await _ensureInitialized();
    if (_closing) throw StateError('Database is closing'); // re-check after suspension
    _activeOperations++;
    try {
      return await fn(_db!);
    } finally {
      _activeOperations--;
      if (_closing && _activeOperations == 0) {
        _drainCompleter?.complete();
      }
    }
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    if (_initFuture != null) {
      try {
        await _initFuture;
      } catch (_) {}
    }
    if (_db == null) {
      _closing = false;
      return;
    }
    if (_activeOperations > 0) {
      _drainCompleter = Completer();
      await _drainCompleter!.future; // waits for in-flight ops to finish
    }
    await _db!.close();
    _db = null;
    _initFuture = null;
    _closing = false;
  }

  /// Ensure database is initialized before operations.
  /// Auto-initializes if not already done (lazy init) to prevent
  /// "Database not initialized" crashes during lifecycle transitions.
  Future<void>? _initFuture;

  Future<void> _ensureInitialized() async {
    if (_db != null) return;
    try {
      MonitoringServiceHelper.logDebug(
        "DATABASE_WAS_UNINITIALIZED",
        {},
      );
      FirebaseCrashlytics.instance
          .log("Database was not initialized; lazy init triggered.");
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: "FAILED_REPORTING_DATABASE_WAS_UNINITIALIZED",
      );
    }
    _initFuture ??= initialize();
    try {
      await _initFuture;
      MonitoringServiceHelper.logDebug(
        "DATABASE_INITIALIZED",
        {},
      );
    } catch (e, st) {
      _initFuture = null; // allow retry on next op
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: "FAILED_TO_INITIALIZE_DATABASE",
      );
      rethrow;
    }
  }

  /// Convert bool values to int (true→1, false→0) for SQLite storage
  Map<String, dynamic> _convertBoolsToInts(Map<String, dynamic> data) {
    final converted = Map<String, dynamic>.from(data);
    for (final key in _boolColumns) {
      if (converted.containsKey(key) && converted[key] is bool) {
        converted[key] = converted[key] == true ? 1 : 0;
      }
    }
    return converted;
  }

  /// Convert int values to bool (1→true, 0→false) for Dart models
  Map<String, dynamic> _convertIntsToBools(Map<String, dynamic> data) {
    final converted = Map<String, dynamic>.from(data);
    for (final key in _boolColumns) {
      if (converted.containsKey(key) && converted[key] is int) {
        converted[key] = converted[key] == 1;
      }
    }
    return converted;
  }
}
