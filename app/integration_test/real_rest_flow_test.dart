import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:naugi/app_controller.dart';
import 'package:naugi/data/kitchen_repository.dart';
import 'package:naugi/data/local_store.dart';
import 'package:naugi/data/recipe_api.dart';
import 'package:naugi/domain/models.dart';
import 'package:naugi/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const apiUrl = String.fromEnvironment('API_BASE_URL');

  testWidgets('Android reaches real REST and restores SQLite when offline', (
    tester,
  ) async {
    expect(apiUrl, isNotEmpty, reason: 'Pass API_BASE_URL via dart-define.');
    // Dedicated notebook: the app's normal guest data is never cleared.
    final local = LocalStore(fileName: 'naugi_real_rest_integration.db');
    await local.remove('guest');
    final online = AppController(
      repository: KitchenRepository(
        local: local,
        api: RecipeApi(baseUrl: apiUrl),
      ),
    );
    await online.initialize();
    expect(online.offline, false);
    expect(online.allRecipes.length, 20);
    expect(online.catalog.length, 25);
    final recipe = online.allRecipes.first;
    await online.addMeal(recipe, DateTime(2026, 10, 19), 'Tối', 4);
    await online.save(
      online.book.copy(
        pantry: [
          const PantryLot(
            id: 'android-rest-lot',
            ingredientId: 'egg',
            amount: 2,
            unit: 'quả',
            expiry: '2099-01-01',
          ),
        ],
        lists: [
          const ShoppingList(
            id: 'android-rest-list',
            name: 'Đi chợ offline',
            items: [],
          ),
        ],
      ),
    );
    final offline = AppController(
      repository: KitchenRepository(
        local: local,
        api: RecipeApi(baseUrl: 'http://10.0.2.2:1'),
      ),
    );
    await offline.initialize();
    expect(offline.offline, true);
    expect(offline.allRecipes.length, 20);
    expect(offline.book.meals.single.recipe.name, recipe.name);
    expect(offline.book.pantry.single.amount, 2);
    expect(offline.book.lists.single.name, 'Đi chợ offline');

    final router = createRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((ref) => offline)],
        child: NauGiApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mua sắm'));
    await tester.pumpAndSettle();
    expect(find.text('Đi chợ offline'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    online.dispose();
    await local.remove('guest');
    await local.close();
  });
}
