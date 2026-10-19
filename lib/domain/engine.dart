import 'dart:math';
import 'models.dart';

({String unit, double factor}) canonicalUnit(String unit) => switch (unit) {
  'kg' => (unit: 'g', factor: 1000),
  'g' => (unit: 'g', factor: 1),
  'l' => (unit: 'ml', factor: 1000),
  'ml' => (unit: 'ml', factor: 1),
  _ => (unit: unit, factor: 1),
};

class NutritionResult {
  final Nutrients total;
  final Set<String> missing;
  const NutritionResult(this.total, this.missing);
  bool get complete => missing.isEmpty;
}

NutritionResult nutrition(
  Recipe recipe,
  Map<String, Ingredient> catalog, {
  int? servings,
}) {
  var total = Nutrients.zero;
  final missing = <String>{};
  final factor = (servings ?? recipe.servings) / recipe.servings;
  for (final item in recipe.items) {
    final ingredient = catalog[item.ingredientId];
    final unit = canonicalUnit(item.unit);
    double? grams;
    if (item.amount != null) {
      if (unit.unit == 'g') grams = item.amount! * unit.factor;
      if ((item.unit == 'quả' || item.unit == 'cái') &&
          ingredient?.gramsPerPiece != null) {
        grams = item.amount! * ingredient!.gramsPerPiece!;
      }
    }
    if (grams == null || ingredient?.per100g == null) {
      missing.add(ingredient?.name ?? item.ingredientId);
    } else {
      total = total + ingredient!.per100g!.scale(grams / 100 * factor);
    }
  }
  return NutritionResult(total, missing);
}

NutritionResult dayNutrition(
  List<MealEntry> meals,
  Map<String, Ingredient> catalog,
) {
  var total = Nutrients.zero;
  final missing = <String>{};
  for (final meal in meals) {
    final result = nutrition(meal.recipe, catalog, servings: meal.servings);
    total = total + result.total;
    missing.addAll(result.missing);
  }
  return NutritionResult(total, missing);
}

/// Amounts are canonicalized; no density or mass-to-count assumptions are made.
List<ShoppingItem> shoppingFor(
  List<MealEntry> meals,
  List<PantryLot> pantry,
  DateTime now, {
  required bool deductPantry,
}) {
  final totals = <String, ShoppingItem>{};
  for (final meal in meals) {
    for (final item in meal.recipe.items) {
      final c = canonicalUnit(item.unit);
      // Unquantified needs remain separate from quantified quantities.
      final key =
          '${item.ingredientId}|${c.unit}|${item.amount == null ? 'unknown' : 'known'}';
      final amount = item.amount == null
          ? null
          : item.amount! * c.factor * meal.servings / meal.recipe.servings;
      final previous = totals[key];
      totals[key] = ShoppingItem(
        id: key,
        ingredientId: item.ingredientId,
        unit: c.unit,
        amount: amount == null ? null : (previous?.amount ?? 0) + amount,
      );
    }
  }
  if (deductPantry) {
    for (final lot in pantry.where((p) => !p.expired(now))) {
      final c = canonicalUnit(lot.unit);
      final key = '${lot.ingredientId}|${c.unit}|known';
      final need = totals[key];
      if (need != null) {
        totals[key] = need.copy(
          amount: max(0, need.amount! - lot.amount * c.factor),
        );
      }
    }
  }
  return totals.values
      .where((i) => i.amount == null || i.amount! > .001)
      .toList();
}

class Suggestion {
  final Recipe recipe;
  final String reason;
  final double score;
  const Suggestion(this.recipe, this.reason, this.score);
}

List<Suggestion> suggest(
  List<Recipe> recipes,
  List<PantryLot> pantry,
  Preferences preferences,
  DateTime now,
) {
  final available = pantry
      .where((p) => !p.expired(now) && p.amount > 0)
      .toList();
  final soon = available
      .where(
        (p) =>
            DateTime.parse(
              p.expiry,
            ).difference(DateTime(now.year, now.month, now.day)).inDays <=
            2,
      )
      .map((p) => p.ingredientId)
      .toSet();
  final ids = available.map((p) => p.ingredientId).toSet();
  final eligible = recipes.where(
    (r) =>
        r.minutes <= preferences.maxMinutes &&
        (!preferences.vegetarian || r.vegetarian) &&
        !r.items.any((i) => preferences.avoided.contains(i.ingredientId)),
  );
  final results = eligible.map((r) {
    final ingredients = r.items.map((i) => i.ingredientId).toSet();
    final matches = ingredients.intersection(ids).length;
    final urgent = ingredients.intersection(soon).length;
    final score =
        (ingredients.isEmpty ? 0 : matches / ingredients.length) * 100 +
        urgent * 15 -
        r.minutes / 100;
    return Suggestion(
      r,
      '$matches/${ingredients.length} nguyên liệu có sẵn'
      '${urgent > 0 ? ' • $urgent loại sắp hết hạn' : ''} • ${r.minutes} phút',
      score,
    );
  }).toList()..sort((a, b) => b.score.compareTo(a.score));
  return results;
}

/// Stable IDs make repeated guest imports idempotent and keep account data intact.
Notebook mergeGuest(Notebook account, Notebook guest) {
  List<T> union<T>(List<T> existing, List<T> incoming, String Function(T) id) {
    final map = {for (final item in incoming) id(item): item};
    for (final item in existing) {
      map[id(item)] = item;
    }
    return map.values.toList();
  }

  return account.copy(
    recipes: union(account.recipes, guest.recipes, (r) => r.id),
    ingredients: union(account.ingredients, guest.ingredients, (i) => i.id),
    meals: union(account.meals, guest.meals, (m) => m.id),
    pantry: union(account.pantry, guest.pantry, (p) => p.id),
    lists: union(account.lists, guest.lists, (l) => l.id),
  );
}
