import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'data/catalog.dart';
import 'data/cloud_store.dart';
import 'data/local_store.dart';
import 'domain/engine.dart';
import 'domain/models.dart';
import 'services/reminders.dart';
import 'services/media.dart';

final appProvider = ChangeNotifierProvider<AppController>(
  (ref) => throw UnimplementedError(),
);
const uuid = Uuid();

class AppController extends ChangeNotifier {
  final NotebookStore local;
  final SupabaseClient? client;
  final Reminders? reminders;
  final CloudStore? _cloudOverride;
  Notebook book = const Notebook();
  bool ready = false, guest = false, busy = false, offline = false;
  bool passwordRecovery = false;
  String? notice;
  int revision = 0;
  int _generation = 0;
  StreamSubscription<AuthState>? _auth;
  String? _loadedUser;
  AppController({
    required this.local,
    this.client,
    this.reminders,
    CloudStore? cloud,
  }) : _cloudOverride = cloud;

  String? get userId => client?.auth.currentUser?.id;
  String get scope => guest ? 'guest' : 'account:$userId';
  bool get signedIn => !guest && userId != null;
  bool get canEdit => ready && !busy && (guest || (!offline && signedIn));
  CloudStore get cloud => _cloudOverride ?? SupabaseStore(client!);
  List<Recipe> get allRecipes => [...book.recipes, ...sampleRecipes];
  Map<String, Ingredient> get catalog => {
    for (final i in baseIngredients) i.id: i,
    for (final i in book.ingredients) i.id: i,
  };
  String ingredientName(String id) => catalog[id]?.name ?? id;
  void setNotice(String? value) {
    notice = value;
    notifyListeners();
  }

  void finishRecovery() {
    passwordRecovery = false;
    notifyListeners();
  }

  void initializationFailed() {
    ready = true;
    setNotice('Không đọc được dữ liệu. Kiểm tra dung lượng và khởi động lại.');
  }

  Future<void> initialize() async {
    _auth = client?.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.passwordRecovery) {
        passwordRecovery = true;
        notifyListeners();
      }
      final id = event.session?.user.id;
      if (id != null && (guest || _loadedUser != id)) {
        unawaited(loadAccount());
      } else if (id == null && _loadedUser != null) {
        unawaited(_sessionEnded());
      }
    });
    if (userId != null) {
      await loadAccount();
    } else {
      ready = true;
      notifyListeners();
    }
  }

  Future<void> enterGuest() async {
    if (userId != null) await logout();
    _generation++;
    guest = true;
    offline = false;
    book = await local.read('guest') ?? const Notebook();
    ready = true;
    notice = null;
    notifyListeners();
    await _schedule();
  }

  Future<void> loadAccount() async {
    final id = userId;
    if (id == null) return;
    final generation = ++_generation;
    _loadedUser = id;
    guest = false;
    ready = false;
    busy = true;
    book = const Notebook();
    notice = null;
    notifyListeners();
    try {
      final cached = await local.read('account:$id');
      if (generation != _generation) return;
      book = cached ?? const Notebook();
      final remote = await cloud.read();
      if (generation != _generation) return;
      book = remote.notebook;
      revision = remote.revision;
      offline = false;
      await local.write('account:$id', book);
    } catch (_) {
      if (generation != _generation) return;
      offline = true;
      notice =
          'Chưa tải được dữ liệu máy chủ. Đang xem bản lưu trên thiết bị; hãy thử đồng bộ lại.';
    } finally {
      if (generation == _generation) {
        ready = true;
        busy = false;
        notifyListeners();
        await _schedule();
      }
    }
  }

  Future<void> save(Notebook next) async {
    if (!canEdit) {
      throw StateError('Cần kết nối và tải dữ liệu trước khi chỉnh sửa.');
    }
    final generation = _generation;
    final currentScope = scope;
    busy = true;
    notice = null;
    notifyListeners();
    try {
      if (!guest) {
        if (client != null) {
          final uploaded = <String, Recipe>{};
          Future<Recipe> upload(Recipe r) async {
            final key = '${r.id}|${r.image}';
            return uploaded[key] ??= await RecipeMedia.upload(r, client!);
          }

          final recipes = <Recipe>[];
          for (final recipe in next.recipes) {
            recipes.add(await upload(recipe));
          }
          final meals = <MealEntry>[];
          for (final meal in next.meals) {
            meals.add(
              MealEntry(
                id: meal.id,
                date: meal.date,
                meal: meal.meal,
                servings: meal.servings,
                recipe: await upload(meal.recipe),
              ),
            );
          }
          next = next.copy(recipes: recipes, meals: meals);
        }
        revision = await cloud.write(next, revision);
        if (generation != _generation) {
          throw StateError('Phiên làm việc đã thay đổi.');
        }
        // Server acknowledgment is authoritative even if local cache then fails.
        book = next;
        try {
          await local.write(currentScope, next);
        } catch (_) {
          notice =
              'Đã lưu máy chủ nhưng chưa cập nhật được bản lưu ngoại tuyến.';
        }
      } else {
        await local.write(currentScope, next);
        if (generation != _generation) {
          throw StateError('Phiên làm việc đã thay đổi.');
        }
        book = next;
      }
    } catch (error) {
      if (generation != _generation) rethrow;
      if (!guest) {
        offline = true;
        notice =
            'Chưa xác nhận lưu. Dữ liệu có thể đã thay đổi trên thiết bị khác; hãy đồng bộ rồi thử lại.';
      }
      rethrow;
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
        await _schedule();
      }
    }
  }

  Future<void> _schedule() async {
    try {
      await reminders?.sync(book, catalog);
    } catch (_) {
      notice =
          'Dữ liệu vẫn được giữ. Chưa lên lịch được thông báo; kiểm tra quyền thông báo trong cài đặt.';
      notifyListeners();
    }
  }

  Future<bool> get hasGuestData async {
    final data = await local.read('guest');
    return data != null &&
        (data.recipes.isNotEmpty ||
            data.ingredients.isNotEmpty ||
            data.meals.isNotEmpty ||
            data.pantry.isNotEmpty ||
            data.lists.isNotEmpty);
  }

  Future<void> importGuest() async {
    if (!signedIn || offline) {
      throw StateError('Đăng nhập và kết nối trước khi chuyển dữ liệu.');
    }
    final data = await local.read('guest');
    if (data == null) return;
    var merged = mergeGuest(book, data);
    if (revision == 0) merged = merged.copy(preferences: data.preferences);
    await save(merged);
    // This only executes after cloud acknowledgment and preserves guest data on failure.
    await local.remove('guest');
  }

  Future<void> _sessionEnded() async {
    final id = _loadedUser;
    _generation++;
    _loadedUser = null;
    guest = false;
    offline = false;
    busy = false;
    book = const Notebook();
    ready = true;
    notice = null;
    if (id != null) await local.remove('account:$id');
    if (id != null) {
      try {
        await RecipeMedia.clearAccount(id);
      } catch (_) {
        /* Retry on next sign out. */
      }
    }
    try {
      await reminders?.cancel();
    } catch (_) {
      /* No scheduled data survives next successful sync. */
    }
    notifyListeners();
  }

  Future<void> logout() async {
    // Capture the scope before Supabase clears the current user.
    final id = userId;
    await client?.auth.signOut(scope: SignOutScope.local);
    await _sessionEnded();
    if (id != null) await local.remove('account:$id');
  }

  Future<void> saveRecipe(Recipe recipe) => save(
    book.copy(
      recipes: [...book.recipes.where((r) => r.id != recipe.id), recipe],
    ),
  );
  Future<void> removeRecipe(String id) =>
      save(book.copy(recipes: book.recipes.where((r) => r.id != id).toList()));
  Future<void> favorite(Recipe recipe) async {
    if (recipe.sample) {
      await saveRecipe(
        recipe.copy(id: uuid.v4(), sample: false, favorite: true),
      );
    } else {
      await saveRecipe(recipe.copy(favorite: !recipe.favorite));
    }
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
  Future<List<Suggestion>> aiSuggestions() async {
    if (!signedIn) throw StateError('Đăng nhập để sử dụng gợi ý AI.');
    final candidates = suggest(
      allRecipes,
      book.pantry,
      book.preferences,
      DateTime.now(),
    ).take(30).toList();
    if (candidates.isEmpty) return [];
    try {
      final result = await client!.functions
          .invoke(
            'suggest-recipes',
            body: {'candidateIds': candidates.map((s) => s.recipe.id).toList()},
          )
          .timeout(const Duration(seconds: 20));
      if (result.status != 200 || result.data is! Map) {
        throw StateError('unavailable');
      }
      final raw = result.data['suggestions'];
      if (raw is! List || raw.isEmpty || raw.length > 5) {
        throw StateError('invalid');
      }
      final byId = {for (final s in candidates) s.recipe.id: s.recipe};
      final seen = <String>{};
      return raw.map((item) {
        final id = item['id'];
        final reason = item['reason'];
        if (!byId.containsKey(id) ||
            !seen.add(id) ||
            reason is! String ||
            reason.isEmpty ||
            reason.length > 300) {
          throw StateError('invalid');
        }
        return Suggestion(byId[id]!, reason, 0);
      }).toList();
    } catch (_) {
      throw StateError('Gợi ý AI hiện không khả dụng. Vui lòng thử lại sau.');
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }
}
