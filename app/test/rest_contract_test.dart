import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:naugi/app_controller.dart';
import 'package:naugi/data/kitchen_repository.dart';
import 'package:naugi/data/local_store.dart';
import 'package:naugi/data/recipe_api.dart';
import 'package:naugi/domain/models.dart';

void main() {
  test(
    'controller to real REST and SQLite supports CRUD and offline restart',
    () async {
      sqfliteFfiInit();
      final originalFactory = databaseFactoryOrNull;
      databaseFactoryOrNull = databaseFactoryFfi;
      final temporary = await Directory.systemTemp.createTemp(
        'naugi-rest-sqlite-',
      );
      final backend = path.normalize(path.absolute('../backend'));
      final database = await File(
        path.join(backend, 'seed.json'),
      ).copy(path.join(temporary.path, 'db.json'));
      final process = await Process.start('node', [
        '-e',
        '''
      const jsonServer = require('json-server');
      const app = jsonServer.create();
      app.use(jsonServer.bodyParser);
      app.use(jsonServer.router(process.argv[1]));
      const server = app.listen(0, '127.0.0.1', () => console.log('PORT=' + server.address().port));
    ''',
        database.path,
      ], workingDirectory: backend);
      final errors = StringBuffer();
      final errorSubscription = process.stderr
          .transform(utf8.decoder)
          .listen(errors.write);
      final stores = <LocalStore>[];
      final controllers = <AppController>[];
      var stopped = false;
      addTearDown(() async {
        for (final app in controllers) {
          app.dispose();
        }
        for (final store in stores) {
          await store.close();
        }
        if (!stopped) {
          process.kill();
          await process.exitCode;
        }
        await errorSubscription.cancel();
        databaseFactoryOrNull = originalFactory;
        final resolved = await temporary.resolveSymbolicLinks();
        final systemTemp = await Directory.systemTemp.resolveSymbolicLinks();
        expect(path.isWithin(systemTemp, resolved), isTrue);
        await Directory(resolved).delete(recursive: true);
      });
      final line = await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((line) => line.startsWith('PORT='))
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () =>
                throw StateError('Backend failed to start: $errors'),
          );
      final url = 'http://127.0.0.1:${line.substring(5)}';
      AppController createApp() {
        final store = LocalStore(
          fileName: path.join(temporary.path, 'notebook.sqlite'),
        );
        stores.add(store);
        final app = AppController(
          repository: KitchenRepository(
            local: store,
            api: RecipeApi(baseUrl: url),
          ),
        );
        controllers.add(app);
        return app;
      }

      final app = createApp();
      await app.initialize();
      expect(app.allRecipes, hasLength(20));
      expect(app.catalog, hasLength(25));
      final recipe = app.allRecipes.first.copy(
        id: 'real-rest-test',
        sample: false,
      );
      await app.saveRecipe(recipe);
      await app.addMeal(recipe, DateTime(2026, 10, 19), 'Tối', 4);
      await app.favorite(recipe);
      final edited = Recipe.fromJson({
        ...recipe.toJson(),
        'name': 'Món kiểm thử REST',
      });
      await app.saveRecipe(edited);
      expect(
        (await app.repository.api.getRecipe(recipe.id))!.name,
        edited.name,
      );
      await app.saveIngredient(
        const Ingredient(id: 'rest-ingredient', name: 'Nguyên liệu REST'),
      );
      expect(app.catalog['rest-ingredient']!.name, 'Nguyên liệu REST');
      await app.removeRecipe(recipe.id);
      expect(await app.repository.api.getRecipe(recipe.id), isNull);
      expect(app.book.meals.single.recipe.name, recipe.name);
      // End the isolated API; no user's backend/database is touched.
      process.kill();
      await process.exitCode;
      stopped = true;
      final restored = createApp();
      await restored.initialize();
      expect(restored.offline, true);
      expect(restored.book.hasRemoteCache, true);
      expect(restored.book.meals.single.servings, 4);
      await restored.save(
        restored.book.copy(
          lists: [
            const ShoppingList(
              id: 'offline-list',
              name: 'Đi chợ offline',
              items: [],
            ),
          ],
        ),
      );
      final restarted = createApp();
      await restarted.initialize();
      expect(restarted.book.lists.single.name, 'Đi chợ offline');
      expect(errors.toString(), isEmpty);
    },
    skip: File('../backend/node_modules/json-server/package.json').existsSync()
        ? false
        : 'Run npm ci in backend before the real REST/SQLite contract test.',
  );
}
