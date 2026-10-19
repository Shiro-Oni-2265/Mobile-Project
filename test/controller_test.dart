import 'package:flutter_test/flutter_test.dart';
import 'package:naugi/app_controller.dart';
import 'package:naugi/data/catalog.dart';
import 'package:naugi/domain/models.dart';
import 'support.dart';

void main() {
  test('guest persists and restores without cloud configuration', () async {
    final local = MemoryStore();
    final app = AppController(local: local);
    await app.initialize();
    expect(app.canEdit, false);
    await app.enterGuest();
    expect(app.canEdit, true);
    await app.saveRecipe(sampleRecipes.first.copy(id: 'mine', sample: false));
    final restored = AppController(local: local);
    await restored.enterGuest();
    expect(restored.book.recipes.single.id, 'mine');
    expect(await restored.hasGuestData, true);
    app.dispose();
    restored.dispose();
  });
  test('failed guest write does not update in-memory state', () async {
    final local = MemoryStore();
    final app = AppController(local: local);
    await app.enterGuest();
    local.failWrites = true;
    await expectLater(app.saveRecipe(sampleRecipes.first), throwsStateError);
    expect(app.book.recipes, isEmpty);
    expect(app.busy, false);
    expect(app.canEdit, true);
    app.dispose();
  });
  test('deleting original does not mutate planned snapshot', () async {
    final app = AppController(local: MemoryStore());
    await app.enterGuest();
    final original = sampleRecipes.first.copy(id: 'mine', sample: false);
    await app.saveRecipe(original);
    await app.addMeal(original, DateTime(2026, 10, 19), 'Tối', 4);
    await app.removeRecipe('mine');
    expect(app.book.recipes, isEmpty);
    expect(app.book.meals.single.recipe.name, original.name);
    expect(app.book.meals.single.servings, 4);
    app.dispose();
  });
  test(
    'guest cannot invoke AI or import without authenticated account',
    () async {
      final app = AppController(local: MemoryStore());
      await app.enterGuest();
      await expectLater(app.aiSuggestions(), throwsStateError);
      await expectLater(app.importGuest(), throwsStateError);
      app.dispose();
    },
  );
  test('ingredient override does not mutate base catalog', () async {
    final app = AppController(local: MemoryStore());
    await app.enterGuest();
    await app.save(
      app.book.copy(
        ingredients: [const Ingredient(id: 'rice', name: 'Gạo của tôi')],
      ),
    );
    expect(app.catalog['rice']!.name, 'Gạo của tôi');
    expect(baseIngredients.first.name, 'Gạo trắng');
    app.dispose();
  });
}
