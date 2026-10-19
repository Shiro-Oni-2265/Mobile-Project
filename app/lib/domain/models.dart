import 'dart:convert';

typedef Json = Map<String, dynamic>;

double number(dynamic value, [double fallback = 0]) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

class Nutrients {
  final double kcal, protein, carbs, fat;
  const Nutrients(this.kcal, this.protein, this.carbs, this.fat);
  static const zero = Nutrients(0, 0, 0, 0);
  Nutrients operator +(Nutrients n) => Nutrients(
    kcal + n.kcal,
    protein + n.protein,
    carbs + n.carbs,
    fat + n.fat,
  );
  Nutrients scale(double factor) =>
      Nutrients(kcal * factor, protein * factor, carbs * factor, fat * factor);
  Json toJson() => {
    'kcal': kcal,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };
  factory Nutrients.fromJson(Json j) => Nutrients(
    number(j['kcal']),
    number(j['protein']),
    number(j['carbs']),
    number(j['fat']),
  );
}

class Ingredient {
  final String id, name;
  final Nutrients? per100g;
  final double? gramsPerPiece;
  final String? source;
  const Ingredient({
    required this.id,
    required this.name,
    this.per100g,
    this.gramsPerPiece,
    this.source,
  });
  Json toJson() => {
    'id': id,
    'name': name,
    'per100g': per100g?.toJson(),
    'gramsPerPiece': gramsPerPiece,
    'source': source,
  };
  factory Ingredient.fromJson(Json j) => Ingredient(
    id: j['id'],
    name: j['name'],
    per100g: j['per100g'] == null
        ? null
        : Nutrients.fromJson(Map<String, dynamic>.from(j['per100g'])),
    gramsPerPiece: j['gramsPerPiece'] == null
        ? null
        : number(j['gramsPerPiece']),
    source: j['source'],
  );
}

class RecipeItem {
  final String ingredientId, unit;
  final double? amount;
  const RecipeItem(this.ingredientId, this.amount, this.unit);
  Json toJson() => {
    'ingredientId': ingredientId,
    'amount': amount,
    'unit': unit,
  };
  factory RecipeItem.fromJson(Json j) => RecipeItem(
    j['ingredientId'],
    j['amount'] == null ? null : number(j['amount']),
    j['unit'],
  );
}

class Recipe {
  final String id, name, description, category;
  final String? image;
  final int minutes, servings;
  final bool vegetarian, favorite, sample;
  final List<RecipeItem> items;
  final List<String> steps;
  const Recipe({
    required this.id,
    required this.name,
    this.description = '',
    this.category = 'Món chính',
    this.image,
    required this.minutes,
    required this.servings,
    this.vegetarian = false,
    this.favorite = false,
    this.sample = false,
    required this.items,
    required this.steps,
  });
  Recipe copy({
    String? id,
    bool? favorite,
    bool? sample,
    String? image,
    bool clearImage = false,
  }) => Recipe(
    id: id ?? this.id,
    name: name,
    description: description,
    category: category,
    image: clearImage ? null : image ?? this.image,
    minutes: minutes,
    servings: servings,
    vegetarian: vegetarian,
    favorite: favorite ?? this.favorite,
    sample: sample ?? this.sample,
    items: List.of(items),
    steps: List.of(steps),
  );
  Json toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'image': image,
    'minutes': minutes,
    'servings': servings,
    'vegetarian': vegetarian,
    'favorite': favorite,
    'sample': sample,
    'items': items.map((i) => i.toJson()).toList(),
    'steps': steps,
  };
  factory Recipe.fromJson(Json j) => Recipe(
    id: j['id'],
    name: j['name'],
    description: j['description'] ?? '',
    category: j['category'] ?? 'Món chính',
    image: j['image'],
    minutes: j['minutes'],
    servings: j['servings'],
    vegetarian: j['vegetarian'] ?? false,
    favorite: j['favorite'] ?? false,
    sample: j['sample'] ?? false,
    items: (j['items'] as List)
        .map((i) => RecipeItem.fromJson(Map<String, dynamic>.from(i)))
        .toList(),
    steps: List<String>.from(j['steps']),
  );
}

class MealEntry {
  final String id, date, meal;
  final int servings;
  final Recipe recipe;
  const MealEntry({
    required this.id,
    required this.date,
    required this.meal,
    required this.servings,
    required this.recipe,
  });
  Json toJson() => {
    'id': id,
    'date': date,
    'meal': meal,
    'servings': servings,
    'recipe': recipe.toJson(),
  };
  factory MealEntry.fromJson(Json j) => MealEntry(
    id: j['id'],
    date: j['date'],
    meal: j['meal'],
    servings: j['servings'],
    recipe: Recipe.fromJson(Map<String, dynamic>.from(j['recipe'])),
  );
}

class PantryLot {
  final String id, ingredientId, unit, expiry;
  final double amount;
  const PantryLot({
    required this.id,
    required this.ingredientId,
    required this.amount,
    required this.unit,
    required this.expiry,
  });
  bool expired(DateTime now) =>
      DateTime.parse(expiry).isBefore(DateTime(now.year, now.month, now.day));
  Json toJson() => {
    'id': id,
    'ingredientId': ingredientId,
    'amount': amount,
    'unit': unit,
    'expiry': expiry,
  };
  factory PantryLot.fromJson(Json j) => PantryLot(
    id: j['id'],
    ingredientId: j['ingredientId'],
    amount: number(j['amount']),
    unit: j['unit'],
    expiry: j['expiry'],
  );
}

class ShoppingItem {
  final String id, ingredientId, unit;
  final double? amount;
  final bool purchased;
  const ShoppingItem({
    required this.id,
    required this.ingredientId,
    required this.unit,
    this.amount,
    this.purchased = false,
  });
  ShoppingItem copy({bool? purchased, double? amount}) => ShoppingItem(
    id: id,
    ingredientId: ingredientId,
    unit: unit,
    amount: amount ?? this.amount,
    purchased: purchased ?? this.purchased,
  );
  Json toJson() => {
    'id': id,
    'ingredientId': ingredientId,
    'unit': unit,
    'amount': amount,
    'purchased': purchased,
  };
  factory ShoppingItem.fromJson(Json j) => ShoppingItem(
    id: j['id'],
    ingredientId: j['ingredientId'],
    unit: j['unit'],
    amount: j['amount'] == null ? null : number(j['amount']),
    purchased: j['purchased'] ?? false,
  );
}

class ShoppingList {
  final String id, name;
  final List<ShoppingItem> items;
  const ShoppingList({
    required this.id,
    required this.name,
    required this.items,
  });
  Json toJson() => {
    'id': id,
    'name': name,
    'items': items.map((i) => i.toJson()).toList(),
  };
  factory ShoppingList.fromJson(Json j) => ShoppingList(
    id: j['id'],
    name: j['name'],
    items: (j['items'] as List)
        .map((i) => ShoppingItem.fromJson(Map<String, dynamic>.from(i)))
        .toList(),
  );
}

class Preferences {
  final bool vegetarian, reminders;
  final int servings, maxMinutes;
  final List<String> avoided;
  const Preferences({
    this.vegetarian = false,
    this.reminders = false,
    this.servings = 2,
    this.maxMinutes = 45,
    this.avoided = const [],
  });
  Json toJson() => {
    'vegetarian': vegetarian,
    'reminders': reminders,
    'servings': servings,
    'maxMinutes': maxMinutes,
    'avoided': avoided,
  };
  factory Preferences.fromJson(Json j) => Preferences(
    vegetarian: j['vegetarian'] ?? false,
    reminders: j['reminders'] ?? false,
    servings: j['servings'] ?? 2,
    maxMinutes: j['maxMinutes'] ?? 45,
    avoided: List<String>.from(j['avoided'] ?? []),
  );
}

class Notebook {
  final int schemaVersion;
  final bool hasRemoteCache;
  final List<String> favoriteIds;
  final Map<String, String> localImages;
  final List<Recipe> draftRecipes;
  final List<Ingredient> draftIngredients;
  final List<Recipe> recipes;
  final List<Ingredient> ingredients;
  final List<MealEntry> meals;
  final List<PantryLot> pantry;
  final List<ShoppingList> lists;
  final Preferences preferences;
  const Notebook({
    this.schemaVersion = 2,
    this.hasRemoteCache = false,
    this.favoriteIds = const [],
    this.localImages = const {},
    this.draftRecipes = const [],
    this.draftIngredients = const [],
    this.recipes = const [],
    this.ingredients = const [],
    this.meals = const [],
    this.pantry = const [],
    this.lists = const [],
    this.preferences = const Preferences(),
  });
  Notebook copy({
    int? schemaVersion,
    bool? hasRemoteCache,
    List<String>? favoriteIds,
    Map<String, String>? localImages,
    List<Recipe>? draftRecipes,
    List<Ingredient>? draftIngredients,
    List<Recipe>? recipes,
    List<Ingredient>? ingredients,
    List<MealEntry>? meals,
    List<PantryLot>? pantry,
    List<ShoppingList>? lists,
    Preferences? preferences,
  }) => Notebook(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    hasRemoteCache: hasRemoteCache ?? this.hasRemoteCache,
    favoriteIds: favoriteIds ?? this.favoriteIds,
    localImages: localImages ?? this.localImages,
    draftRecipes: draftRecipes ?? this.draftRecipes,
    draftIngredients: draftIngredients ?? this.draftIngredients,
    recipes: recipes ?? this.recipes,
    ingredients: ingredients ?? this.ingredients,
    meals: meals ?? this.meals,
    pantry: pantry ?? this.pantry,
    lists: lists ?? this.lists,
    preferences: preferences ?? this.preferences,
  );
  Json toJson() => {
    'schemaVersion': schemaVersion,
    'hasRemoteCache': hasRemoteCache,
    'favoriteIds': favoriteIds,
    'localImages': localImages,
    'draftRecipes': draftRecipes.map((x) => x.toJson()).toList(),
    'draftIngredients': draftIngredients.map((x) => x.toJson()).toList(),
    'recipes': recipes.map((x) => x.toJson()).toList(),
    'ingredients': ingredients.map((x) => x.toJson()).toList(),
    'meals': meals.map((x) => x.toJson()).toList(),
    'pantry': pantry.map((x) => x.toJson()).toList(),
    'lists': lists.map((x) => x.toJson()).toList(),
    'preferences': preferences.toJson(),
  };
  factory Notebook.fromJson(Json j) => Notebook(
    schemaVersion: j['schemaVersion'] as int? ?? 1,
    hasRemoteCache: j['hasRemoteCache'] as bool? ?? false,
    favoriteIds: List<String>.from(j['favoriteIds'] ?? const []),
    localImages: Map<String, String>.from(j['localImages'] ?? const {}),
    draftRecipes: _objects(j['draftRecipes'], Recipe.fromJson),
    draftIngredients: _objects(j['draftIngredients'], Ingredient.fromJson),
    recipes: _objects(j['recipes'], Recipe.fromJson),
    ingredients: _objects(j['ingredients'], Ingredient.fromJson),
    meals: _objects(j['meals'], MealEntry.fromJson),
    pantry: _objects(j['pantry'], PantryLot.fromJson),
    lists: _objects(j['lists'], ShoppingList.fromJson),
    preferences: Preferences.fromJson(
      Map<String, dynamic>.from(j['preferences'] ?? {}),
    ),
  );
  String encode() => jsonEncode(toJson());
}

List<T> _objects<T>(dynamic data, T Function(Json) build) =>
    (data as List? ?? [])
        .map((j) => build(Map<String, dynamic>.from(j)))
        .toList();

String dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String quantity(double? value) => value == null
    ? 'Vừa đủ'
    : value != 0 && value.abs() < .001
    ? value.toStringAsPrecision(3)
    : value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
