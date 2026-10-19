import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:naugi/app_controller.dart';
import 'package:naugi/data/catalog.dart';
import 'package:naugi/data/local_store.dart';
import 'package:naugi/domain/engine.dart';
import 'package:naugi/domain/models.dart';
import 'package:naugi/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real SQLite guest notebook survives restart and supports full planning flow',
    (tester) async {
      // Separate database: never clears the user's actual NauGi notebook.
      final local = LocalStore(fileName: 'naugi_integration.db');
      await local.remove('guest');
      final app = AppController(local: local);
      await app.enterGuest();
      final recipe = sampleRecipes[1].copy(
        id: 'integration-recipe',
        sample: false,
      );
      await app.saveRecipe(recipe);
      await app.addMeal(recipe, DateTime.now(), 'Tối', 4);
      await app.save(
        app.book.copy(
          pantry: [
            PantryLot(
              id: 'integration-lot',
              ingredientId: 'egg',
              amount: 2,
              unit: 'quả',
              expiry: dayKey(DateTime.now().add(const Duration(days: 1))),
            ),
          ],
        ),
      );
      final shopping = shoppingFor(
        app.book.meals,
        app.book.pantry,
        DateTime.now(),
        deductPantry: true,
      );
      expect(shopping.singleWhere((i) => i.ingredientId == 'egg').amount, 4);
      await app.save(
        app.book.copy(
          lists: [
            ShoppingList(
              id: 'integration-list',
              name: 'Đi chợ thử',
              items: shopping,
            ),
          ],
        ),
      );
      final restored = AppController(local: local);
      await restored.enterGuest();
      expect(restored.book.encode(), app.book.encode());
      final router = createRouter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => restored)],
          child: NauGiApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Khách'), findsOneWidget);
      await tester.tap(find.text('Mua sắm'));
      await tester.pumpAndSettle();
      expect(find.text('Đi chợ thử'), findsOneWidget);
      expect(find.text('Trứng gà'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(restored.book.lists.single.items.first.purchased, true);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      app.dispose();
      await local.remove('guest');
      await (await local.database).close();
    },
  );
}
