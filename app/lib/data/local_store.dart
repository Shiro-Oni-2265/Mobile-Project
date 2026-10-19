import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

abstract class NotebookStore {
  Future<Notebook?> read(String scope);
  Future<void> write(String scope, Notebook notebook);
  Future<void> remove(String scope);
}

class LocalStore implements NotebookStore {
  final String fileName;
  LocalStore({this.fileName = 'naugi.db'});
  Database? _db;
  Future<Database> get database async => _db ??= await openDatabase(
    path.join(await getDatabasesPath(), fileName),
    version: 2,
    onCreate: (db, _) => db.execute(
      'CREATE TABLE notebooks (scope TEXT PRIMARY KEY, payload TEXT NOT NULL)',
    ),
    onUpgrade: (db, oldVersion, newVersion) async {
      // SQLite runs upgrades in a transaction. Preserve the *raw* v1 guest
      // payload before the repository transforms it; account scopes stay intact.
      if (oldVersion < 2) {
        await db.execute(
          'INSERT OR IGNORE INTO notebooks (scope, payload) '
          'SELECT ?, payload FROM notebooks WHERE scope = ?',
          ['migration-backup-v1', 'guest'],
        );
      }
    },
  );
  @override
  Future<Notebook?> read(String scope) async {
    final rows = await (await database).query(
      'notebooks',
      where: 'scope = ?',
      whereArgs: [scope],
    );
    return rows.isEmpty
        ? null
        : Notebook.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(rows.first['payload'] as String),
            ),
          );
  }

  @override
  Future<void> write(String scope, Notebook notebook) async {
    await (await database).insert('notebooks', {
      'scope': scope,
      'payload': notebook.encode(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> remove(String scope) async {
    await (await database).delete(
      'notebooks',
      where: 'scope = ?',
      whereArgs: [scope],
    );
  }

  Future<void> close() async {
    final opened = _db;
    _db = null;
    await opened?.close();
  }
}
