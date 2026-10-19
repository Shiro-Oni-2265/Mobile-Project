import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naugi/data/catalog.dart';
import 'package:naugi/data/kitchen_repository.dart';
import 'package:naugi/data/recipe_api.dart';
import 'package:naugi/data/local_store.dart';
import 'package:naugi/domain/models.dart';

class MemoryStore implements NotebookStore {
  final Map<String, Notebook> data = {};
  bool failWrites = false;
  @override
  Future<Notebook?> read(String scope) async => data[scope];
  @override
  Future<void> write(String scope, Notebook notebook) async {
    if (failWrites) throw StateError('Disk full');
    data[scope] = Notebook.fromJson(notebook.toJson());
  }

  @override
  Future<void> remove(String scope) async {
    data.remove(scope);
  }
}

class TestApiServer {
  bool offline = false;
  int? status;
  final Map<String, Json> recipes = {
    for (final r in sampleRecipes) r.id: r.toJson(),
  };
  final Map<String, Json> ingredients = {
    for (final i in baseIngredients) i.id: i.toJson(),
  };
  KitchenRepository repository(NotebookStore local) => KitchenRepository(
    local: local,
    api: RecipeApi(
      baseUrl: 'http://test.invalid:3000',
      client: MockClient(handle),
    ),
  );
  Future<http.Response> handle(http.Request request) async {
    if (offline) throw const SocketException('Offline');
    if (status != null) return http.Response('{}', status!);
    final parts = request.url.pathSegments;
    final table = parts.first == 'recipes' ? recipes : ingredients;
    final id = parts.length > 1 ? parts[1] : null;
    Object? result;
    var code = 200;
    switch (request.method) {
      case 'GET':
        result = id == null ? table.values.toList() : table[id];
        if (result == null) {
          code = 404;
          result = {};
        }
      case 'POST':
        final row = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        table[row['id'] as String] = row;
        result = row;
        code = 201;
      case 'PUT':
        if (!table.containsKey(id)) {
          code = 404;
          result = {};
        } else {
          result = table[id!] = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
        }
      case 'DELETE':
        table.remove(id);
        result = {};
      default:
        code = 405;
        result = {};
    }
    return http.Response(
      jsonEncode(result),
      code,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
