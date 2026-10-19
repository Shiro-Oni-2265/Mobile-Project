import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naugi/data/kitchen_repository.dart';
import 'package:naugi/data/recipe_api.dart';
import 'package:naugi/domain/app_failure.dart';
import 'package:naugi/domain/models.dart';

import 'support.dart';

const dish = Recipe(
  id: 'r1',
  name: 'Canh',
  minutes: 10,
  servings: 2,
  items: [],
  steps: [],
);
const ingredient = Ingredient(id: 'i1', name: 'Rau');
RecipeApi apiWith(Future<http.Response> Function(http.Request) handler) =>
    RecipeApi(baseUrl: 'https://example.org', client: MockClient(handler));
http.Response collection(http.Request r) => response(
  jsonEncode(
    r.url.path.endsWith('recipes') ? [dish.toJson()] : [ingredient.toJson()],
  ),
  200,
);

http.Response response(String body, int status) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test(
    'legacy guest migration keeps backup, drafts and local metadata',
    () async {
      final store = MemoryStore();
      store.data['guest'] = Notebook.fromJson({
        'schemaVersion': 1,
        'recipes': [dish.copy(favorite: true, image: '/local.jpg').toJson()],
        'ingredients': [ingredient.toJson()],
      });
      store.data['account-1'] = const Notebook(recipes: [dish]);
      final repo = KitchenRepository(
        local: store,
        api: apiWith((r) async => collection(r)),
      );
      await repo.initialize();
      expect(store.data['migration-backup-v1']!.recipes.single.id, 'r1');
      expect(repo.book.recipes, isEmpty);
      expect(repo.book.draftRecipes.single.id, 'r1');
      expect(repo.book.favoriteIds, contains('r1'));
      expect(repo.book.localImages['r1'], '/local.jpg');
      expect(store.data['account-1']!.recipes, hasLength(1));
      await repo.refresh();
      expect(repo.book.recipes.single.favorite, true);
      expect(repo.book.recipes.single.image, '/local.jpg');
    },
  );
  test(
    'successful empty remote data is a valid cache across restart',
    () async {
      final store = MemoryStore();
      final api = apiWith((_) async => response('[]', 200));
      final repo = KitchenRepository(local: store, api: api);
      await repo.initialize();
      expect(repo.hasCache, false);
      await repo.refresh();
      expect(repo.hasCache, true);
      final restored = KitchenRepository(local: store, api: api);
      await restored.initialize();
      expect(restored.hasCache, true);
    },
  );
  test('failed coherent refresh retains previous cache', () async {
    final store = MemoryStore();
    store.data['guest'] = const Notebook(recipes: [dish], hasRemoteCache: true);
    final repo = KitchenRepository(
      local: store,
      api: apiWith(
        (r) async => r.url.path.endsWith('ingredients')
            ? response('{}', 500)
            : response('[]', 200),
      ),
    );
    await repo.initialize();
    await expectLater(repo.refresh(), throwsA(isA<AppFailure>()));
    expect(repo.book.recipes.single.id, 'r1');
  });
  test('local write failure does not publish an unsaved notebook', () async {
    final store = MemoryStore();
    final repo = KitchenRepository(
      local: store,
      api: apiWith((r) async => collection(r)),
    );
    await repo.initialize();
    store.failWrites = true;
    await expectLater(
      repo.saveLocal(
        repo.book.copy(preferences: const Preferences(servings: 8)),
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(repo.book.preferences.servings, 2);
  });
  test(
    'in-flight refresh preserves local favorites and planner edits',
    () async {
      final gate = Completer<void>();
      final repo = KitchenRepository(
        local: MemoryStore(),
        api: apiWith((r) async {
          await gate.future;
          return collection(r);
        }),
      );
      await repo.initialize();
      final refresh = repo.refresh();
      await repo.toggleFavorite('r1');
      await repo.saveLocal(
        repo.book.copy(preferences: const Preferences(servings: 9)),
      );
      gate.complete();
      await refresh;
      expect(repo.book.recipes.single.favorite, true);
      expect(repo.book.preferences.servings, 9);
    },
  );
  test(
    'remote ack survives disk failure and stale saveLocal snapshots',
    () async {
      final store = MemoryStore();
      final repo = KitchenRepository(
        local: store,
        api: apiWith((r) async {
          if (r.method == 'GET') {
            return response('{}', 404);
          }
          return response(r.body, 201);
        }),
      );
      await repo.initialize();
      final stale = repo.book;
      store.failWrites = true;
      await repo.saveRecipe(dish);
      expect(repo.book.recipes.single.id, 'r1');
      expect(repo.notice, isNotNull);
      store.failWrites = false;
      await repo.saveLocal(
        stale.copy(preferences: const Preferences(servings: 3)),
      );
      expect(repo.book.recipes.single.id, 'r1');
    },
  );
  test('sample mutations never reach the API', () async {
    var requests = 0;
    final store = MemoryStore();
    store.data['guest'] = Notebook(
      recipes: [dish.copy(sample: true)],
      hasRemoteCache: true,
    );
    final repo = KitchenRepository(
      local: store,
      api: apiWith((r) async {
        requests++;
        return response('{}', 200);
      }),
    );
    await repo.initialize();
    await expectLater(repo.saveRecipe(dish), throwsA(isA<AppFailure>()));
    await expectLater(repo.removeRecipe('r1'), throwsA(isA<AppFailure>()));
    expect(requests, 0);
  });
  test(
    'draft import orders ingredients first and retains failed drafts',
    () async {
      final requests = <String>[];
      final store = MemoryStore();
      store.data['guest'] = const Notebook(
        draftRecipes: [dish],
        draftIngredients: [ingredient],
      );
      final repo = KitchenRepository(
        local: store,
        api: apiWith((r) async {
          requests.add('${r.method} ${r.url.path}');
          if (r.method == 'GET') {
            return response('{}', 404);
          }
          if (r.url.path == '/recipes') {
            return response('{}', 503);
          }
          return response(r.body, 201);
        }),
      );
      await repo.initialize();
      await expectLater(repo.importDrafts(), throwsA(isA<AppFailure>()));
      expect(requests, [
        'GET /ingredients/i1',
        'POST /ingredients',
        'GET /recipes/r1',
        'POST /recipes',
      ]);
      expect(repo.book.draftIngredients, isEmpty);
      expect(repo.book.draftRecipes, hasLength(1));
    },
  );
  test('older refresh cannot undo a remote mutation or local edits', () async {
    final gate = Completer<void>();
    final collectionsStarted = Completer<void>();
    var collectionCalls = 0;
    var remote = dish;
    final store = MemoryStore();
    store.data['guest'] = const Notebook(recipes: [dish], hasRemoteCache: true);
    final repo = KitchenRepository(
      local: store,
      api: apiWith((r) async {
        if (r.method == 'PUT') {
          remote = Recipe.fromJson(jsonDecode(r.body));
          return response(r.body, 200);
        }
        if (r.url.path == '/recipes/r1') {
          return response(jsonEncode(remote.toJson()), 200);
        }
        final stale = collection(r);
        if (++collectionCalls == 2) {
          collectionsStarted.complete();
        }
        await gate.future;
        return stale;
      }),
    );
    await repo.initialize();
    final refresh = repo.refresh();
    await collectionsStarted.future;
    final edited = Recipe.fromJson({...dish.toJson(), 'name': 'Canh mới'});
    await repo.saveRecipe(edited);
    await repo.toggleFavorite('r1');
    await repo.saveLocal(
      repo.book.copy(preferences: const Preferences(servings: 7)),
    );
    gate.complete();
    await refresh;
    expect(repo.book.recipes.single.name, 'Canh mới');
    expect(repo.book.recipes.single.favorite, true);
    expect(repo.book.preferences.servings, 7);
  });
  test(
    'uncertain creation rechecks ID and acknowledges without duplicate POST',
    () async {
      Recipe? remote;
      var posts = 0;
      final api = RecipeApi(
        baseUrl: 'https://example.org',
        timeout: const Duration(milliseconds: 10),
        client: MockClient((r) async {
          if (r.method == 'GET') {
            return remote == null
                ? response('{}', 404)
                : response(jsonEncode(remote!.toJson()), 200);
          }
          posts++;
          remote = Recipe.fromJson(jsonDecode(r.body));
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return response(r.body, 201);
        }),
      );
      final repo = KitchenRepository(local: MemoryStore(), api: api);
      await repo.initialize();
      await expectLater(
        repo.saveRecipe(dish),
        throwsA(
          isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.timeout),
        ),
      );
      expect(repo.book.recipes, isEmpty);
      await repo.saveRecipe(dish);
      expect(posts, 1);
      expect(repo.book.recipes.single.id, 'r1');
    },
  );
  test(
    'import retains conflicting drafts without overwriting remote',
    () async {
      var posts = 0;
      final different = Recipe.fromJson({
        ...dish.toJson(),
        'name': 'Người khác',
      });
      final store = MemoryStore();
      store.data['guest'] = const Notebook(draftRecipes: [dish]);
      final repo = KitchenRepository(
        local: store,
        api: apiWith((r) async {
          if (r.method != 'GET') {
            posts++;
          }
          return response(jsonEncode(different.toJson()), 200);
        }),
      );
      await repo.initialize();
      await repo.importDrafts();
      expect(posts, 0);
      expect(repo.book.draftRecipes.single.name, dish.name);
      expect(repo.notice, isNotNull);
    },
  );
  test(
    'migration backup failure preserves legacy guest before replacement',
    () async {
      final store = MemoryStore();
      store.data['guest'] = Notebook.fromJson({
        'schemaVersion': 1,
        'recipes': [dish.toJson()],
      });
      store.failWrites = true;
      final repo = KitchenRepository(
        local: store,
        api: apiWith((r) async => collection(r)),
      );
      await expectLater(repo.initialize(), throwsA(isA<AppFailure>()));
      expect(store.data['guest']!.schemaVersion, 1);
      expect(store.data['guest']!.recipes.single.id, 'r1');
    },
  );
  test(
    'local photo edited during remote save survives acknowledgement',
    () async {
      final gate = Completer<void>();
      final writing = Completer<void>();
      final store = MemoryStore();
      store.data['guest'] = const Notebook(
        recipes: [dish],
        hasRemoteCache: true,
      );
      final repo = KitchenRepository(
        local: store,
        api: apiWith((r) async {
          if (r.method == 'GET') {
            return response(jsonEncode(dish.toJson()), 200);
          }
          writing.complete();
          await gate.future;
          return response(r.body, 200);
        }),
      );
      await repo.initialize();
      final edited = Recipe.fromJson({...dish.toJson(), 'name': 'Canh mới'});
      final saving = repo.saveRecipe(edited);
      await writing.future;
      await repo.setLocalImage('r1', '/new-photo.jpg');
      await repo.toggleFavorite('r1');
      gate.complete();
      await saving;
      expect(repo.book.recipes.single.image, '/new-photo.jpg');
      expect(repo.book.recipes.single.favorite, true);
    },
  );
  test(
    'local photo preserves existing remote image without remote write',
    () async {
      const url = 'https://example.org/remote.jpg';
      final store = MemoryStore();
      store.data['guest'] = Notebook(
        recipes: [dish.copy(image: url)],
        hasRemoteCache: true,
      );
      final repo = KitchenRepository(
        local: store,
        api: apiWith((r) async {
          if (r.method == 'GET') {
            return response(jsonEncode(dish.copy(image: url).toJson()), 200);
          }
          fail('Only a local photo changed: no remote write is needed.');
        }),
      );
      await repo.initialize();
      await repo.saveRecipe(dish.copy(image: '/device/photo.jpg'));
      expect(repo.book.localImages['r1'], '/device/photo.jpg');
      expect(repo.book.recipes.single.image, '/device/photo.jpg');
      await repo.setLocalImage('r1', null);
      expect(repo.book.localImages, isEmpty);
      expect(repo.book.recipes.single.image, url);
      final restored = KitchenRepository(
        local: store,
        api: apiWith((r) async => collection(r)),
      );
      await restored.initialize();
      expect(restored.book.recipes.single.image, url);
    },
  );
  test(
    'photo-only save does not publish when local persistence fails',
    () async {
      final store = MemoryStore();
      store.data['guest'] = const Notebook(
        recipes: [dish],
        hasRemoteCache: true,
      );
      final repo = KitchenRepository(
        local: store,
        api: apiWith((r) async => response(jsonEncode(dish.toJson()), 200)),
      );
      await repo.initialize();
      store.failWrites = true;
      await expectLater(
        repo.saveRecipe(dish.copy(image: '/photo.jpg')),
        throwsA(
          isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.storage),
        ),
      );
      expect(repo.book.localImages, isEmpty);
      expect(repo.book.recipes.single.image, isNull);
    },
  );
}
