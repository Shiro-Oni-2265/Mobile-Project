import 'package:flutter_test/flutter_test.dart';
import 'package:naugi/data/catalog.dart';
import 'package:naugi/domain/engine.dart';
import 'package:naugi/domain/models.dart';

const recipe = Recipe(
  id: 'r',
  name: 'Món thử',
  minutes: 20,
  servings: 2,
  items: [RecipeItem('rice', 200, 'g')],
  steps: ['Nấu chín'],
);
MealEntry meal(Recipe r, {int servings = 2}) => MealEntry(
  id: 'm',
  date: '2026-10-19',
  meal: 'Tối',
  servings: servings,
  recipe: r,
);
final catalog = {for (final i in baseIngredients) i.id: i};

void main() {
  test('small fractional quantities remain nonzero and retain precision', () {
    expect(quantity(.01), '0.01');
    expect(quantity(12.55), '12.55');
    expect(quantity(100), '100');
    expect(quantity(0), '0');
    expect(quantity(.00001), isNot('0'));
  });
  test('nutrition scales quantities and servings without modifying source', () {
    final original = nutrition(recipe, catalog);
    final doubled = nutrition(recipe, catalog, servings: 4);
    expect(original.total.kcal, 730);
    expect(doubled.total.kcal, 1460);
    expect(doubled.total.protein, closeTo(original.total.protein * 2, .001));
    expect(recipe.items.first.amount, 200);
    expect(original.complete, true);
  });
  test(
    'unknown nutrition, unquantified and unsupported units remain explicit',
    () {
      const r = Recipe(
        id: 'x',
        name: 'x',
        minutes: 1,
        servings: 1,
        steps: ['x'],
        items: [
          RecipeItem('rice', 100, 'g'),
          RecipeItem('fishsauce', 10, 'ml'),
          RecipeItem('salt', null, 'g'),
          RecipeItem('chicken', 1, 'bó'),
        ],
      );
      final n = nutrition(r, catalog);
      expect(n.total.kcal, 365);
      expect(n.missing, {'Nước mắm', 'Muối', 'Ức gà'});
      expect(n.complete, false);
    },
  );
  test('piece conversion is for nutrition only and ml is not treated as g', () {
    const r = Recipe(
      id: 'x',
      name: 'x',
      minutes: 1,
      servings: 1,
      steps: ['x'],
      items: [RecipeItem('egg', 2, 'quả'), RecipeItem('oil', 10, 'ml')],
    );
    final n = nutrition(r, catalog);
    expect(n.total.kcal, 143);
    expect(n.missing, {'Dầu ăn'});
  });
  test('daily totals use planned serving count', () {
    expect(
      dayNutrition([
        meal(recipe),
        meal(recipe, servings: 4),
      ], catalog).total.kcal,
      2190,
    );
  });
  test('shopping canonicalizes kg/g and applies servings', () {
    const kg = Recipe(
      id: 'kg',
      name: 'kg',
      minutes: 1,
      servings: 2,
      items: [RecipeItem('rice', .3, 'kg')],
      steps: ['x'],
    );
    final items = shoppingFor(
      [meal(recipe, servings: 4), meal(kg)],
      [],
      DateTime(2026, 10, 19),
      deductPantry: false,
    );
    expect(items.length, 1);
    expect(items.single.amount, 700);
    expect(items.single.unit, 'g');
    expect(recipe.items.first.amount, 200);
  });
  test('multiple lots deduct once; expired lots and unlike units excluded', () {
    final lots = [
      const PantryLot(
        id: '1',
        ingredientId: 'rice',
        amount: .1,
        unit: 'kg',
        expiry: '2026-10-19',
      ),
      const PantryLot(
        id: '2',
        ingredientId: 'rice',
        amount: 50,
        unit: 'g',
        expiry: '2026-10-20',
      ),
      const PantryLot(
        id: '3',
        ingredientId: 'rice',
        amount: 500,
        unit: 'g',
        expiry: '2026-10-18',
      ),
      const PantryLot(
        id: '4',
        ingredientId: 'rice',
        amount: 99,
        unit: 'bó',
        expiry: '2026-10-20',
      ),
    ];
    final items = shoppingFor(
      [meal(recipe)],
      lots,
      DateTime(2026, 10, 19, 17),
      deductPantry: true,
    );
    expect(items.single.amount, 50);
    expect(lots.first.amount, .1);
    expect(
      shoppingFor(
        [meal(recipe)],
        lots,
        DateTime(2026, 10, 19),
        deductPantry: false,
      ).single.amount,
      200,
    );
  });
  test('surplus stock never produces negative shopping quantity', () {
    final items = shoppingFor(
      [meal(recipe)],
      [
        const PantryLot(
          id: '1',
          ingredientId: 'rice',
          amount: 1,
          unit: 'kg',
          expiry: '2026-10-20',
        ),
      ],
      DateTime(2026, 10, 19),
      deductPantry: true,
    );
    expect(items, isEmpty);
  });
  test('unquantified and quantified needs do not swallow each other', () {
    const r = Recipe(
      id: 'x',
      name: 'x',
      minutes: 1,
      servings: 2,
      steps: ['x'],
      items: [
        RecipeItem('salt', null, 'g'),
        RecipeItem('salt', 2, 'g'),
        RecipeItem('salt', null, 'g'),
      ],
    );
    final items = shoppingFor(
      [meal(r)],
      [],
      DateTime(2026, 10, 19),
      deductPantry: true,
    );
    expect(items.length, 2);
    expect(items.where((i) => i.amount == null).length, 1);
    expect(items.where((i) => i.amount != null).single.amount, 2);
  });
  test('expiry is inclusive through end of day', () {
    const lot = PantryLot(
      id: '1',
      ingredientId: 'rice',
      amount: 1,
      unit: 'g',
      expiry: '2026-10-19',
    );
    expect(lot.expired(DateTime(2026, 10, 19, 23, 59)), false);
    expect(lot.expired(DateTime(2026, 10, 20)), true);
  });
  test('independent suggestions filter diet, avoided ingredients and time', () {
    final results = suggest(
      sampleRecipes,
      [],
      const Preferences(vegetarian: true, maxMinutes: 20, avoided: ['tofu']),
      DateTime(2026, 10, 19),
    );
    expect(results, isNotEmpty);
    expect(
      results.every(
        (s) =>
            s.recipe.vegetarian &&
            s.recipe.minutes <= 20 &&
            !s.recipe.items.any((i) => i.ingredientId == 'tofu'),
      ),
      true,
    );
  });
  test('soon-expiring usable stock raises matching recipes', () {
    final results = suggest(
      sampleRecipes,
      [
        const PantryLot(
          id: 'p',
          ingredientId: 'mushroom',
          amount: 200,
          unit: 'g',
          expiry: '2026-10-20',
        ),
      ],
      const Preferences(vegetarian: true, maxMinutes: 20),
      DateTime(2026, 10, 19),
    );
    expect(
      results.first.recipe.items.any((i) => i.ingredientId == 'mushroom'),
      true,
    );
    expect(results.first.reason, contains('sắp hết hạn'));
  });
  test('guest merging is idempotent and account wins stable-ID collisions', () {
    const guest = Notebook(
      recipes: [recipe],
      preferences: Preferences(vegetarian: true),
    );
    final account = Notebook(recipes: [recipe.copy(favorite: true)]);
    final twice = mergeGuest(mergeGuest(account, guest), guest);
    expect(twice.recipes.length, 1);
    expect(twice.recipes.single.favorite, true);
    expect(twice.preferences.vegetarian, false);
  });
  test('JSON round trip preserves snapshots, missing amounts and flags', () {
    final book = Notebook(
      recipes: [recipe.copy(favorite: true)],
      meals: [meal(recipe, servings: 3)],
      lists: const [
        ShoppingList(
          id: 'l',
          name: 'Đi chợ',
          items: [
            ShoppingItem(
              id: 's',
              ingredientId: 'salt',
              unit: 'g',
              purchased: true,
            ),
          ],
        ),
      ],
    );
    final restored = Notebook.fromJson(book.toJson());
    expect(restored.encode(), book.encode());
    expect(restored.meals.single.servings, 3);
    expect(restored.lists.single.items.single.amount, null);
  });
  test('20 valid samples reference known ingredients', () {
    expect(sampleRecipes.length, 20);
    expect(sampleRecipes.map((r) => r.id).toSet().length, 20);
    for (final r in sampleRecipes) {
      expect(r.servings, greaterThan(0));
      expect(r.steps, isNotEmpty);
      expect(r.items.every((i) => catalog.containsKey(i.ingredientId)), true);
    }
  });
}
