import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:chameleonultragui/models/key_record.dart';

class KeyDatabase {
  static Database? _database;
  static const String _tableName = 'keys';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'keys.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        sak INTEGER NOT NULL,
        atqa TEXT NOT NULL,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        entrance INTEGER NOT NULL,
        lat REAL,
        lon REAL,
        tag INTEGER NOT NULL,
        data TEXT NOT NULL,
        ats TEXT NOT NULL,
        signature TEXT,
        version TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertKey(KeyRecord key) async {
    Database db = await database;
    Map<String, dynamic> map = key.toMap();
    map.remove('id');
    map['atqa'] = jsonEncode(map['atqa']);
    map['data'] = jsonEncode(map['data']);
    map['ats'] = jsonEncode(map['ats']);
    if (map['signature'] != null) map['signature'] = jsonEncode(map['signature']);
    if (map['version'] != null) map['version'] = jsonEncode(map['version']);
    return await db.insert(_tableName, map);
  }

  Future<List<KeyRecord>> getAllKeys() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(_tableName, orderBy: 'address ASC');
    return maps.map((map) => _fromDbMap(map)).toList();
  }

  Future<KeyRecord?> getKeyById(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _fromDbMap(maps.first);
  }

  Future<KeyRecord?> getKeyByUid(String uid) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'uid = ?',
      whereArgs: [uid],
    );
    if (maps.isEmpty) return null;
    return _fromDbMap(maps.first);
  }

  Future<List<KeyRecord>> searchKeys(String query) async {
    Database db = await database;
    String searchQuery = '%$query%';
    List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'address LIKE ? OR name LIKE ?',
      whereArgs: [searchQuery, searchQuery],
      orderBy: 'address ASC',
    );
    return maps.map((map) => _fromDbMap(map)).toList();
  }

  Future<List<KeyRecord>> getNearestKeys(double lat, double lon, {int limit = 5}) async {
    List<KeyRecord> allKeys = await getAllKeys();
    for (var key in allKeys) {
      key.updatedAt = DateTime.now();
    }
    allKeys.sort((a, b) {
      double? distA = a.distanceTo(lat, lon);
      double? distB = b.distanceTo(lat, lon);
      if (distA == null && distB == null) return 0;
      if (distA == null) return 1;
      if (distB == null) return -1;
      return distA.compareTo(distB);
    });
    return allKeys.where((key) => key.distanceTo(lat, lon) != null).take(limit).toList();
  }

  Future<int> updateKey(KeyRecord key) async {
    Database db = await database;
    key.updatedAt = DateTime.now();
    Map<String, dynamic> map = key.toMap();
    map['atqa'] = jsonEncode(map['atqa']);
    map['data'] = jsonEncode(map['data']);
    map['ats'] = jsonEncode(map['ats']);
    if (map['signature'] != null) map['signature'] = jsonEncode(map['signature']);
    if (map['version'] != null) map['version'] = jsonEncode(map['version']);
    return await db.update(
      _tableName,
      map,
      where: 'id = ?',
      whereArgs: [key.id],
    );
  }

  Future<int> deleteKey(int id) async {
    Database db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> exportToJson() async {
    List<KeyRecord> keys = await getAllKeys();
    List<Map<String, dynamic>> jsonList = keys.map((k) => k.toMap()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  Future<int> importFromJson(String jsonString) async {
    List<dynamic> jsonList = jsonDecode(jsonString);
    int count = 0;
    for (var json in jsonList) {
      try {
        KeyRecord key = KeyRecord.fromMap(json);
        await insertKey(key);
        count++;
      } catch (e) {
        continue;
      }
    }
    return count;
  }

  Future<int> getKeyCount() async {
    Database db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearAll() async {
    Database db = await database;
    await db.delete(_tableName);
  }

  KeyRecord _fromDbMap(Map<String, dynamic> map) {
    map['atqa'] = jsonDecode(map['atqa'] as String);
    map['data'] = jsonDecode(map['data'] as String);
    map['ats'] = jsonDecode(map['ats'] as String);
    if (map['signature'] != null) {
      map['signature'] = jsonDecode(map['signature'] as String);
    }
    if (map['version'] != null) {
      map['version'] = jsonDecode(map['version'] as String);
    }
    return KeyRecord.fromMap(map);
  }
}