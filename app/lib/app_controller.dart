import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import 'data/kitchen_repository.dart';
import 'domain/app_failure.dart';
import 'domain/load_state.dart';
import 'domain/models.dart';
import 'services/media.dart';
import 'services/reminders.dart';

final appProvider = ChangeNotifierProvider<AppController>(
  (ref) => throw UnimplementedError(),
);
const uuid = Uuid();

/// ViewModel: publishes UI state; all persisted data goes through repository.
class AppController extends ChangeNotifier {
  final KitchenRepository repository;
  final Reminders? reminders;
  AppController({required this.repository, this.reminders});
  Notebook get book => repository.book;
  bool ready = false, busy = false, offline = false;
  bool _savingLocal = false, _disposed = false;
  bool _refreshDeferred = false;
  int _refresh = 0;
  String? notice;
  AppFailure? localFailure;
  LoadState<List<Recipe>> catalogState = const LoadState(LoadStatus.loading);
  bool get canEdit => ready && !_savingLocal;
  bool get canWriteRemote => ready && !busy;
  List<Recipe> get allRecipes => book.recipes;
  Map<String, Ingredient> get catalog => {
    for (final i in book.ingredients) i.id: i,
  };
  String ingredientName(String id) => catalog[id]?.name ?? id;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void setNotice(String? value) {
    notice = value;
    _emit();
  }

  Future<void> initialize() async {
    ready = false;
    localFailure = null;
    _emit();
    try {
      await repository.initialize();
      ready = true;
      _emit();
      await refresh();
      await _schedule();
    } catch (error) {
      localFailure = error is AppFailure
          ? error
          : const AppFailure(
              'Không đọc được dữ liệu trên thiết bị. Vui lòng thử lại.',
              kind: FailureKind.storage,
            );
      _emit();
    }
  }

  Future<void> refresh() async {
    final request = ++_refresh;
    catalogState = LoadState(
      LoadStatus.loading,
      data: repository.hasCache ? allRecipes : null,
    );
    _emit();
    try {
      final applied = await repository.refresh();
      if (request != _refresh) return;
      if (!applied) {
        // A write invalidated this response. Do not turn an unknown catalog
        // into an empty success; re-read once the write has finished.
        if (busy) {
          _refreshDeferred = true;
        } else {
          await refresh();
        }
        return;
      }
      offline = false;
      notice = repository.notice;
      _catalogLoaded();
    } catch (error) {
      if (request != _refresh) return;
      offline = true;
      final failure = error is AppFailure
          ? error
          : const AppFailure(
              'Không tải được thư viện. Vui lòng thử lại.',
              kind: FailureKind.network,
            );
      catalogState = LoadState(
        LoadStatus.error,
        data: repository.hasCache ? allRecipes : null,
        failure: failure,
      );
    }
    _emit();
  }

  void _catalogLoaded() {
    catalogState = LoadState(
      allRecipes.isEmpty ? LoadStatus.empty : LoadStatus.success,
      data: allRecipes,
    );
  }

  Future<void> save(Notebook next) async {
    if (!canEdit) throw StateError('Đang lưu dữ liệu. Vui lòng chờ.');
    _savingLocal = true;
    _emit();
    try {
      await repository.saveLocal(next);
      notice = repository.notice;
      await _schedule();
    } finally {
      _savingLocal = false;
      _emit();
    }
  }

  Future<void> _remote(Future<void> Function() action) async {
    if (!canWriteRemote) throw StateError('Đang gửi thay đổi. Vui lòng chờ.');
    busy = true;
    _emit();
    try {
      await action();
      offline = false;
      notice = repository.notice;
      if (repository.hasCache) {
        _catalogLoaded();
      } else {
        _refreshDeferred = true;
      }
    } finally {
      busy = false;
      _emit();
      if (_refreshDeferred || catalogState.status == LoadStatus.loading) {
        _refreshDeferred = false;
        final operationNotice = notice;
        await refresh();
        if (operationNotice != null && notice != operationNotice) {
          notice = notice == null
              ? operationNotice
              : '$operationNotice $notice';
          _emit();
        }
      }
    }
  }

  Future<void> saveRecipe(Recipe recipe) =>
      _remote(() => repository.saveRecipe(recipe));
  Future<void> removeRecipe(String id) =>
      _remote(() => repository.removeRecipe(id));
  Future<void> saveIngredient(Ingredient ingredient) =>
      _remote(() => repository.saveIngredient(ingredient));
  Future<void> importDrafts() => _remote(repository.importDrafts);
  Future<void> favorite(Recipe recipe) async {
    await repository.toggleFavorite(recipe.id);
    _emit();
  }

  Future<String?> pickRecipeImage() => RecipeMedia.pick();
  Future<void> setRecipeImage(String id, String? path) async {
    await repository.setLocalImage(id, path);
    _emit();
  }

  Future<void> changeRecipePhoto(String id) async {
    final path = await pickRecipeImage();
    if (path != null) await setRecipeImage(id, path);
  }

  Future<bool> requestRemindersPermission() async =>
      await reminders?.requestPermission() ?? false;
  Future<void> testReminder() async {
    await reminders?.test();
  }

  Future<void> addMeal(
    Recipe recipe,
    DateTime day,
    String meal,
    int servings,
  ) => save(
    book.copy(
      meals: [
        ...book.meals,
        MealEntry(
          id: uuid.v4(),
          date: dayKey(day),
          meal: meal,
          servings: servings,
          recipe: Recipe.fromJson(recipe.toJson()),
        ),
      ],
    ),
  );

  Future<void> _schedule() async {
    try {
      await reminders?.sync(book, catalog);
    } catch (_) {
      notice =
          'Dữ liệu đã lưu. Chưa lên lịch được thông báo; kiểm tra quyền trong Cài đặt.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    repository.api.close();
    super.dispose();
  }
}
