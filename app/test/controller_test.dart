import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naugi/app_controller.dart';
import 'package:naugi/data/catalog.dart';
import 'package:naugi/data/kitchen_repository.dart';
import 'package:naugi/data/recipe_api.dart';
import 'package:naugi/domain/load_state.dart';
import 'package:naugi/domain/models.dart';

import 'support.dart';

void main() {
  test('starts without login and caches the remote catalog', () async {
    final app = AppController(
      repository: TestApiServer().repository(MemoryStore()),
    );
    await app.initialize();
    expect(app.ready, true);
    expect(app.allRecipes.length, 20);
    expect(app.canEdit, true);
    app.dispose();
  });
  test('offline permits local planning and favorites', () async {
    final local = MemoryStore();
    final server = TestApiServer();
    final first = AppController(repository: server.repository(local));
    await first.initialize();
    server.offline = true;
    final app = AppController(repository: server.repository(local));
    await app.initialize();
    expect(app.offline, true);
    final recipe = app.allRecipes.first;
    await app.favorite(recipe);
    await app.addMeal(recipe, DateTime(2026, 10, 19), 'Tối', 4);
    expect(app.allRecipes.first.favorite, true);
    expect(app.book.meals.single.servings, 4);
    await expectLater(
      app.saveRecipe(recipe.copy(id: 'new', sample: false)),
      throwsException,
    );
    expect(app.busy, false);
    expect(app.canEdit, true);
    first.dispose();
    app.dispose();
  });
  test('remote deletion preserves planned snapshot', () async {
    final app = AppController(
      repository: TestApiServer().repository(MemoryStore()),
    );
    await app.initialize();
    final recipe = sampleRecipes.first.copy(id: 'mine', sample: false);
    await app.saveRecipe(recipe);
    await app.addMeal(recipe, DateTime(2026, 10, 19), 'Tối', 4);
    await app.removeRecipe(recipe.id);
    expect(app.allRecipes.where((r) => r.id == recipe.id), isEmpty);
    expect(app.book.meals.single.recipe.name, recipe.name);
    app.dispose();
  });
  test('local failure does not publish unsaved data', () async {
    final local = MemoryStore();
    final app = AppController(repository: TestApiServer().repository(local));
    await app.initialize();
    local.failWrites = true;
    await expectLater(
      app.save(
        app.book.copy(
          lists: [const ShoppingList(id: 'new', name: 'Chợ', items: [])],
        ),
      ),
      throwsException,
    );
    expect(app.book.lists, isEmpty);
    expect(app.busy, false);
    app.dispose();
  });

  test(
    'first refresh recovers when a successful write invalidates its result',
    () async {
      final server = TestApiServer();
      final gate = HeldFirstCatalog(server);
      final app = controllerWithClient(gate.handle);
      addTearDown(app.dispose);
      final initialization = app.initialize();
      await gate.started.future;
      expect(app.ready, isTrue);
      expect(app.catalogState.status, LoadStatus.loading);
      await app.saveIngredient(
        const Ingredient(id: 'during-load', name: 'Thêm trong lúc tải'),
      );
      gate.release.complete();
      await initialization;
      expect(app.catalogState.status, LoadStatus.success);
      expect(app.book.hasRemoteCache, isTrue);
      expect(app.allRecipes, hasLength(20));
      expect(app.catalog.containsKey('during-load'), isTrue);
    },
  );

  test(
    'first refresh recovers when a failed write invalidates its result',
    () async {
      final server = TestApiServer();
      final gate = HeldFirstCatalog(server);
      final app = controllerWithClient(gate.handle);
      addTearDown(app.dispose);
      final initialization = app.initialize();
      await gate.started.future;
      gate.failMutations = true;
      await expectLater(
        app.saveIngredient(
          const Ingredient(id: 'failed-during-load', name: 'Chưa gửi được'),
        ),
        throwsException,
      );
      gate.failMutations = false;
      gate.release.complete();
      await initialization;
      expect(app.catalogState.status, LoadStatus.success);
      expect(app.book.hasRemoteCache, isTrue);
      expect(app.allRecipes, hasLength(20));
      expect(app.catalog.containsKey('failed-during-load'), isFalse);
    },
  );

  test(
    'successful ingredient write does not turn failed catalog into empty',
    () async {
      final server = TestApiServer();
      final app = controllerWithClient((request) async {
        if (request.method == 'GET' && request.url.pathSegments.length == 1) {
          return http.Response('{}', 503);
        }
        return server.handle(request);
      });
      addTearDown(app.dispose);
      await app.initialize();
      expect(app.catalogState.status, LoadStatus.error);
      expect(app.book.hasRemoteCache, isFalse);
      await app.saveIngredient(
        const Ingredient(
          id: 'after-error',
          name: 'Ghi được nhưng chưa tải danh mục',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(app.catalog.containsKey('after-error'), isTrue);
      expect(app.catalogState.status, LoadStatus.error);
      expect(app.book.hasRemoteCache, isFalse);
    },
  );
  test('offline photo persists and clears without HTTP', () async {
    final store = MemoryStore();
    final server = TestApiServer();
    var requests = 0;
    final app = AppController(
      repository: KitchenRepository(
        local: store,
        api: RecipeApi(
          baseUrl: 'http://test.invalid:3000',
          client: MockClient((request) {
            requests++;
            return server.handle(request);
          }),
        ),
      ),
    );
    addTearDown(app.dispose);
    await app.initialize();
    final id = app.allRecipes.first.id;
    final originalRemoteImage = server.recipes[id]!['image'];
    final requestsBefore = requests;
    server.offline = true;
    await app.setRecipeImage(id, '/device/private/photo.jpg');
    expect(requests, requestsBefore);
    expect(store.data['guest']!.localImages[id], '/device/private/photo.jpg');
    expect(app.allRecipes.first.image, '/device/private/photo.jpg');
    expect(server.recipes[id]!['image'], originalRemoteImage);
    await app.setRecipeImage(id, null);
    expect(requests, requestsBefore);
    expect(store.data['guest']!.localImages.containsKey(id), isFalse);
    expect(app.allRecipes.first.image, originalRemoteImage);
  });
}

AppController controllerWithClient(
  Future<http.Response> Function(http.Request) handle,
) => AppController(
  repository: KitchenRepository(
    local: MemoryStore(),
    api: RecipeApi(
      baseUrl: 'http://test.invalid:3000',
      client: MockClient(handle),
    ),
  ),
);

/// Snapshot the first pair before waiting, as a real response can already be
/// stale when a mutation completes while that response is in transit.
class HeldFirstCatalog {
  final TestApiServer server;
  final started = Completer<void>();
  final release = Completer<void>();
  int heldRequests = 0;
  bool failMutations = false;
  HeldFirstCatalog(this.server);

  Future<http.Response> handle(http.Request request) async {
    final collection =
        request.method == 'GET' && request.url.pathSegments.length == 1;
    if (!collection && failMutations) return http.Response('{}', 503);
    if (collection && heldRequests < 2) {
      heldRequests++;
      final response = await server.handle(request);
      if (heldRequests == 2 && !started.isCompleted) started.complete();
      await release.future;
      return response;
    }
    return server.handle(request);
  }
}
