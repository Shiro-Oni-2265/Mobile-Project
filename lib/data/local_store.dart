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
    version: 1,
    onCreate: (db, _) => db.execute(
      'CREATE TABLE notebooks (scope TEXT PRIMARY KEY, payload TEXT NOT NULL)',
    ),
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
}
