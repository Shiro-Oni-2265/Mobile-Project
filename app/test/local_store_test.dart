import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naugi/data/kitchen_repository.dart';
import 'package:naugi/data/local_store.dart';
import 'package:naugi/data/recipe_api.dart';
import 'package:naugi/domain/models.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const legacyRecipe = Recipe(
  id: 'old-recipe',
  name: 'Canh rau',
  minutes: 12,
  servings: 2,
  favorite: true,
  image: 'C:/photos/canh.jpg',
  items: [RecipeItem('old-ingredient', 100, 'g')],
  steps: ['Nấu chín'],
);

void main() {
  late Directory temporary;
  late String file;
  DatabaseFactory? originalFactory;
  LocalStore? store;
  RecipeApi? api;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    originalFactory = sqlite.databaseFactoryOrNull;
    sqlite.databaseFactoryOrNull = databaseFactoryFfi;
    temporary = await Directory.systemTemp.createTemp('naugi-sqlite-');
    file = path.join(temporary.path, 'notebook.db');
  });
  tearDown(() async {
    await store?.close();
    store = null;
    api?.close();
    api = null;
    sqlite.databaseFactoryOrNull = originalFactory;
    // Only the unique temporary directory created by this test is removed.
    final resolved = await temporary.resolveSymbolicLinks();
    final temporaryRoot = await Directory.systemTemp.resolveSymbolicLinks();
    expect(path.isWithin(temporaryRoot, resolved), true);
    await Directory(resolved).delete(recursive: true);
  });

  test(
    'SQLite v1 upgrade backs up raw guest and never changes account scope',
    () async {
      const legacy = Notebook(
        recipes: [legacyRecipe],
        ingredients: [Ingredient(id: 'old-ingredient', name: 'Rau')],
        meals: [
          MealEntry(
            id: 'meal',
            date: '2026-10-19',
            meal: 'Trưa',
            servings: 3,
            recipe: legacyRecipe,
          ),
        ],
        pantry: [
          PantryLot(
            id: 'lot',
            ingredientId: 'old-ingredient',
            amount: 250,
            unit: 'g',
            expiry: '2027-01-01',
          ),
        ],
        lists: [
          ShoppingList(
            id: 'list',
            name: 'Đi chợ',
            items: [
              ShoppingItem(
                id: 'buy',
                ingredientId: 'old-ingredient',
                unit: 'g',
                amount: 100,
                purchased: true,
              ),
            ],
          ),
        ],
        preferences: Preferences(servings: 3),
      );
      final guestPayload = jsonEncode({
        ...legacy.toJson(),
        'schemaVersion': 1,
        'unknownLegacyKey': ['retain raw bytes'],
      });
      final accountPayload = jsonEncode({
        ...legacy.toJson(),
        'schemaVersion': 1,
        'accountOnlyField': 'unchanged',
      });
      final old = await sqlite.openDatabase(
        file,
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE notebooks (scope TEXT PRIMARY KEY, payload TEXT NOT NULL)',
        ),
      );
      try {
        await old.insert('notebooks', {
          'scope': 'guest',
          'payload': guestPayload,
        });
        await old.insert('notebooks', {
          'scope': 'account-private',
          'payload': accountPayload,
        });
      } finally {
        await old.close();
      }

      store = LocalStore(fileName: file);
      api = RecipeApi(
        baseUrl: 'https://example.org',
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      final repository = KitchenRepository(local: store!, api: api!);
      await repository.initialize();
      final upgraded = await store!.database;
      expect(path.normalize(upgraded.path), path.normalize(file));
      expect(await upgraded.getVersion(), 2);
      final rows = await upgraded.query('notebooks');
      final payloads = {
        for (final row in rows)
          row['scope'] as String: row['payload'] as String,
      };
      expect(payloads['migration-backup-v1'], guestPayload);
      expect(payloads['account-private'], accountPayload);
      expect(jsonDecode(payloads['guest']!)['schemaVersion'], 2);
      expect(repository.book.recipes, isEmpty);
      expect(repository.book.ingredients, isEmpty);
      expect(repository.hasCache, false);
      expect(repository.book.draftRecipes.single.id, legacyRecipe.id);
      expect(repository.book.draftIngredients.single.id, 'old-ingredient');
      expect(repository.book.favoriteIds, [legacyRecipe.id]);
      expect(repository.book.localImages[legacyRecipe.id], legacyRecipe.image);
      expect(
        repository.book.meals.single.toJson(),
        legacy.meals.single.toJson(),
      );
      expect(
        repository.book.pantry.single.toJson(),
        legacy.pantry.single.toJson(),
      );
      expect(
        repository.book.lists.single.toJson(),
        legacy.lists.single.toJson(),
      );
      expect(repository.book.preferences.servings, 3);

      await store!.close();
      store = LocalStore(fileName: file);
      final restarted = KitchenRepository(local: store!, api: api!);
      await restarted.initialize();
      expect(restarted.book.draftRecipes, hasLength(1));
      expect(restarted.book.draftIngredients, hasLength(1));
      final afterRestart = await (await store!.database).query('notebooks');
      expect(
        afterRestart.singleWhere(
          (r) => r['scope'] == 'migration-backup-v1',
        )['payload'],
        guestPayload,
      );
      expect(
        afterRestart.singleWhere(
          (r) => r['scope'] == 'account-private',
        )['payload'],
        accountPayload,
      );
    },
  );

  test(
    'successful empty cache and local data survive SQLite close and offline restart',
    () async {
      store = LocalStore(fileName: file);
      api = RecipeApi(
        baseUrl: 'https://example.org',
        client: MockClient((_) async => http.Response('[]', 200)),
      );
      final repository = KitchenRepository(local: store!, api: api!);
      await repository.initialize();
      expect(repository.hasCache, false);
      await repository.refresh();
      await repository.saveLocal(
        repository.book.copy(preferences: const Preferences(servings: 6)),
      );
      expect(repository.hasCache, true);
      await store!.close();
      api!.close();
      store = LocalStore(fileName: file);
      api = RecipeApi(
        baseUrl: 'https://example.org',
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      final offline = KitchenRepository(local: store!, api: api!);
      await offline.initialize();
      expect(offline.hasCache, true);
      expect(offline.book.recipes, isEmpty);
      expect(offline.book.ingredients, isEmpty);
      expect(offline.book.preferences.servings, 6);
      await expectLater(offline.refresh(), throwsA(isA<Exception>()));
      expect(offline.hasCache, true);
      expect(offline.book.preferences.servings, 6);
    },
  );
}
