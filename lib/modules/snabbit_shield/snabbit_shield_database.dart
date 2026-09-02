import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ShieldDatabase {
  static ShieldDatabase? _instance;
  Database? _db;

  ShieldDatabase._();

  static ShieldDatabase get instance => _instance ??= ShieldDatabase._();

  Future<void> initialize() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'snabbit_shield.db');
    _db = await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1/v2 used a structurally incompatible schema — only those are dropped.
    // From v3 onward, migrate IN PLACE (ADD COLUMN) to PRESERVE pending uploads
    // across app updates. Dropping queued clips is silent data loss for a
    // safety feature, so it is no longer done for compatible upgrades.
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS snabbit_shield_uploads');
      await _createTable(db);
      return;
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE snabbit_shield_uploads ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE snabbit_shield_uploads ADD COLUMN next_attempt_at INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 5) {
      // Add index on next_attempt_at so processQueue() WHERE clause is indexed
      // (previously caused a full table scan on every connectivity event).
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_shield_next_attempt ON snabbit_shield_uploads (next_attempt_at)');
    }
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE snabbit_shield_uploads (
        id                        INTEGER PRIMARY KEY AUTOINCREMENT,
        booking_id                INTEGER NOT NULL,
        timestamp                 INTEGER NOT NULL,
        encrypted_audio_bytes     BLOB NOT NULL,
        encryption_metadata_json  TEXT NOT NULL,
        duration_seconds          INTEGER NOT NULL,
        is_sos                    INTEGER NOT NULL DEFAULT 0,
        created_at                INTEGER NOT NULL,
        retry_count               INTEGER NOT NULL DEFAULT 0,
        next_attempt_at           INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_shield_created
      ON snabbit_shield_uploads (created_at)
    ''');
    await db.execute('''
      CREATE INDEX idx_shield_next_attempt
      ON snabbit_shield_uploads (next_attempt_at)
    ''');
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    return await _db!.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> query(String table,
      {List<String>? columns,
      String? where,
      List<dynamic>? whereArgs,
      String? orderBy,
      int? limit}) async {
    return await _db!.query(table,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit);
  }

  Future<int> delete(String table,
      {String? where, List<dynamic>? whereArgs}) async {
    return await _db!.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<int> update(String table, Map<String, dynamic> data,
      {String? where, List<dynamic>? whereArgs}) async {
    return await _db!.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
