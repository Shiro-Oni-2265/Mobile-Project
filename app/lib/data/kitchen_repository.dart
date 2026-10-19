import 'dart:convert';

import '../domain/app_failure.dart';
import '../domain/models.dart';
import 'local_store.dart';
import 'recipe_api.dart';

/// The only writer of the guest notebook. Network waits never hold the local
/// commit queue, so planning and favorites remain usable during a slow request.
class KitchenRepository {
  final NotebookStore local;
  final RecipeApi api;
  Notebook _book = const Notebook();
  // Persist remote image URLs and apply local overlays only on reads.
  Notebook get book => _decorate(_book);
  bool get hasCache => _book.hasRemoteCache;
  String? notice;
  Future<void> _commits = Future<void>.value();
  int _generation = 0, _refreshId = 0, _activeMutations = 0;
  KitchenRepository({required this.local, required this.api});

  Future<void> initialize() => _serialize(() async {
    try {
      var saved = await local.read('guest') ?? const Notebook();
      if (saved.schemaVersion < 2) {
        // Backup must succeed before replacing legacy content with a cache.
        if (await local.read('migration-backup-v1') == null) {
          await local.write('migration-backup-v1', saved);
        }
        final favorites = {
          ...saved.favoriteIds,
          ...saved.recipes.where((r) => r.favorite).map((r) => r.id),
        };
        final images = Map<String, String>.of(saved.localImages);
        for (final recipe in saved.recipes) {
          final image = recipe.image;
          if (image != null && !_remoteImage(image)) {
            images[recipe.id] = image;
          }
        }
        saved = saved.copy(
          schemaVersion: 2,
          recipes: [],
          ingredients: [],
          hasRemoteCache: false,
          favoriteIds: favorites.toList(),
          localImages: images,
          draftRecipes: [...saved.draftRecipes, ...saved.recipes],
          draftIngredients: [...saved.draftIngredients, ...saved.ingredients],
        );
        await local.write('guest', saved);
      }
      _book = saved;
    } catch (_) {
      throw const AppFailure(
        'Không đọc hoặc chuyển đổi được dữ liệu trên thiết bị. Bản gốc được giữ lại.',
        kind: FailureKind.storage,
      );
    }
  });

  Future<bool> refresh() async {
    final request = ++_refreshId;
    final generation = _generation;
    // Future.wait waits for both; no partial recipe/ingredient cache is saved.
    final values = await Future.wait<Object>([
      api.getRecipes(),
      api.getIngredients(),
    ]);
    var applied = false;
    await _serialize(() async {
      if (request != _refreshId ||
          generation != _generation ||
          _activeMutations > 0) {
        return;
      }
      final next = _book.copy(
        recipes: values[0] as List<Recipe>,
        ingredients: values[1] as List<Ingredient>,
        hasRemoteCache: true,
      );
      await _persist(next, remoteAcknowledged: true);
      applied = true;
    });
    return applied;
  }

  /// Only local fields are accepted. A caller's old snapshot cannot roll back
  /// freshly acknowledged remote recipes or the successful-empty cache marker.
  Future<void> saveLocal(Notebook next) => _commit(
    (current) => current.copy(
      meals: next.meals,
      pantry: next.pantry,
      lists: next.lists,
      preferences: next.preferences,
    ),
  );

  Future<void> toggleFavorite(String id) => _commit((current) {
    final ids = current.favoriteIds.toSet();
    if (!ids.remove(id)) {
      ids.add(id);
    }
    return current.copy(favoriteIds: ids.toList());
  });
  Future<void> setLocalImage(String id, String? path) => _commit((current) {
    final images = Map<String, String>.of(current.localImages);
    if (path == null) {
      images.remove(id);
    } else {
      images[id] = path;
    }
    return current.copy(localImages: images);
  });

  Future<void> saveRecipe(Recipe recipe) async {
    _guardSample(recipe.id, proposed: recipe);
    final known = _book.recipes.any((r) => r.id == recipe.id);
    final imageAtStart = _book.localImages[recipe.id];
    await _mutate(() async {
      // Rechecking the client-assigned ID makes retry after an uncertain POST
      // safe. A different remote record with that ID is a collision, not an edit.
      final existing = await api.getRecipe(recipe.id);
      if (existing?.sample == true) {
        _sampleFailure();
      }
      final localImage = recipe.image != null && !_remoteImage(recipe.image!)
          ? recipe.image
          : null;
      final preserveRemoteImage =
          localImage != null || (recipe.image == null && imageAtStart != null);
      final remoteRecipe = preserveRemoteImage
          ? Recipe.fromJson({...recipe.toJson(), 'image': existing?.image})
          : recipe;
      var remoteChanged = !known;
      Recipe saved;
      if (existing != null && _sameRecipe(existing, remoteRecipe)) {
        saved = existing;
      } else if (existing != null && !known) {
        throw const AppFailure(
          'Mã công thức đã tồn tại trên máy chủ. Hãy tạo bản sao với mã mới.',
          kind: FailureKind.http,
          statusCode: 409,
        );
      } else if (known) {
        if (existing == null) {
          throw const AppFailure(
            'Công thức đã bị xóa trên máy chủ. Hãy tải lại danh sách.',
            kind: FailureKind.http,
            statusCode: 404,
          );
        }
        saved = await api.updateRecipe(remoteRecipe);
        remoteChanged = true;
      } else {
        saved = await api.createRecipe(remoteRecipe);
        remoteChanged = true;
      }
      await _commit((current) {
        final images = Map<String, String>.of(current.localImages);
        // A later device-only photo edit wins over this older network request.
        if (current.localImages[recipe.id] == imageAtStart) {
          if (localImage == null) {
            images.remove(recipe.id);
          } else {
            images[recipe.id] = localImage;
          }
        }
        return current.copy(
          recipes: _upsert(current.recipes, saved, (x) => x.id),
          localImages: images,
        );
      }, remoteAcknowledged: remoteChanged);
    });
  }

  Future<void> removeRecipe(String id) async {
    _guardSample(id);
    await _mutate(() async {
      final existing = await api.getRecipe(id);
      if (existing?.sample == true) {
        _sampleFailure();
      }
      if (existing != null) {
        await api.deleteRecipe(id);
      }
      await _commit(
        (current) => current.copy(
          recipes: current.recipes.where((r) => r.id != id).toList(),
        ),
        remoteAcknowledged: true,
      );
    });
  }

  Future<void> saveIngredient(Ingredient ingredient) async {
    final known = _book.ingredients.any((i) => i.id == ingredient.id);
    await _mutate(() async {
      final existing = await api.getIngredient(ingredient.id);
      Ingredient saved;
      if (existing != null &&
          jsonEncode(existing.toJson()) == jsonEncode(ingredient.toJson())) {
        saved = existing;
      } else if (existing != null && !known) {
        throw const AppFailure(
          'Mã nguyên liệu đã tồn tại. Hãy tạo mã mới.',
          kind: FailureKind.http,
          statusCode: 409,
        );
      } else if (known) {
        if (existing == null) {
          throw const AppFailure(
            'Nguyên liệu đã bị xóa trên máy chủ. Hãy tải lại.',
            kind: FailureKind.http,
            statusCode: 404,
          );
        }
        saved = await api.updateIngredient(ingredient);
      } else {
        saved = await api.createIngredient(ingredient);
      }
      await _commit(
        (current) => current.copy(
          ingredients: _upsert(current.ingredients, saved, (x) => x.id),
        ),
        remoteAcknowledged: true,
      );
    });
  }

  /// Called only after the UI explains that import writes drafts to the API.
  /// Each acknowledged record is checkpointed before moving to the next one.
  Future<void> importDrafts() async {
    final conflicts = <String>{};
    var skipped = false;
    try {
      for (final draft in List<Ingredient>.of(_book.draftIngredients)) {
        await _mutate(() async {
          final existing = await api.getIngredient(draft.id);
          if (existing != null &&
              jsonEncode(existing.toJson()) != jsonEncode(draft.toJson())) {
            conflicts.add(draft.id);
            skipped = true;
            return;
          }
          final saved = existing ?? await api.createIngredient(draft);
          await _commit(
            (current) => current.copy(
              ingredients: _upsert(current.ingredients, saved, (x) => x.id),
              draftIngredients: current.draftIngredients
                  .where((i) => i.id != draft.id)
                  .toList(),
            ),
            remoteAcknowledged: true,
          );
        });
      }
      for (final draft in List<Recipe>.of(_book.draftRecipes)) {
        if (draft.items.any((item) => conflicts.contains(item.ingredientId))) {
          skipped = true;
          continue;
        }
        await _mutate(() async {
          final existing = await api.getRecipe(draft.id);
          if (existing != null && !_sameRecipe(existing, draft)) {
            skipped = true;
            return;
          }
          final saved =
              existing ?? await api.createRecipe(draft.copy(sample: false));
          await _commit(
            (current) => current.copy(
              recipes: _upsert(current.recipes, saved, (x) => x.id),
              draftRecipes: current.draftRecipes
                  .where((r) => r.id != draft.id)
                  .toList(),
            ),
            remoteAcknowledged: true,
          );
        });
      }
    } finally {
      if (skipped) {
        const conflictNotice =
            'Một số bản nháp trùng mã nhưng khác nội dung máy chủ. Các bản nháp đó được giữ lại; hãy tạo bản sao với mã mới.';
        notice = notice == null ? conflictNotice : '$notice $conflictNotice';
      }
    }
  }

  void _guardSample(String id, {Recipe? proposed}) {
    if (proposed?.sample == true ||
        _book.recipes.any((r) => r.id == id && r.sample)) {
      _sampleFailure();
    }
  }

  Never _sampleFailure() => throw const AppFailure(
    'Công thức mẫu chỉ được xem. Hãy tạo bản sao để chỉnh sửa.',
    kind: FailureKind.http,
    statusCode: 403,
  );

  Future<void> _mutate(Future<void> Function() action) async {
    _activeMutations++;
    _generation++;
    try {
      await action();
    } finally {
      _activeMutations--;
      _generation++;
    }
  }

  Future<void> _commit(
    Notebook Function(Notebook) transform, {
    bool remoteAcknowledged = false,
  }) => _serialize(() async {
    await _persist(transform(_book), remoteAcknowledged: remoteAcknowledged);
  });

  Future<void> _persist(
    Notebook next, {
    required bool remoteAcknowledged,
  }) async {
    try {
      await local.write('guest', next);
      _book = next;
      notice = null;
    } catch (_) {
      if (remoteAcknowledged) {
        // The server is already changed: never tell the user the write failed
        // or roll memory back, since retrying could duplicate a creation.
        _book = next;
        notice =
            'Máy chủ đã cập nhật nhưng chưa lưu được bộ nhớ thiết bị. Hãy thử tải lại khi có thể.';
      } else {
        throw const AppFailure(
          'Không lưu được dữ liệu trên thiết bị. Vui lòng thử lại.',
          kind: FailureKind.storage,
        );
      }
    }
  }

  Future<void> _serialize(Future<void> Function() action) {
    final result = _commits.then((_) => action());
    // An individual failure must not poison later commits.
    _commits = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Notebook _decorate(Notebook value) => value.copy(
    recipes: value.recipes
        .map(
          (recipe) => recipe.copy(
            favorite: value.favoriteIds.contains(recipe.id),
            image: value.localImages[recipe.id],
          ),
        )
        .toList(),
  );
}

List<T> _upsert<T>(List<T> values, T value, String Function(T) id) => [
  ...values.where((x) => id(x) != id(value)),
  value,
];
bool _remoteImage(String image) {
  final uri = Uri.tryParse(image);
  return uri != null &&
      ['http', 'https'].contains(uri.scheme) &&
      uri.host.isNotEmpty;
}

bool _sameRecipe(Recipe a, Recipe b) {
  Json remote(Recipe r) => r.toJson()
    ..remove('favorite')
    ..['image'] = r.image != null && _remoteImage(r.image!) ? r.image : null;
  return jsonEncode(remote(a)) == jsonEncode(remote(b));
}
