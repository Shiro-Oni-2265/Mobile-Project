import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naugi/data/recipe_api.dart';
import 'package:naugi/domain/app_failure.dart';
import 'package:naugi/domain/models.dart';

const recipe = Recipe(
  id: 'r1',
  name: 'Canh',
  minutes: 10,
  servings: 2,
  favorite: true,
  image: '/private/photo.jpg',
  items: [],
  steps: ['Nấu'],
);

http.Response response(String body, int status) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test(
    'reads configured collection and sends safe remote write fields',
    () async {
      final seen = <http.Request>[];
      final api = RecipeApi(
        baseUrl: 'https://example.org/api/',
        client: MockClient((r) async {
          seen.add(r);
          if (r.method == 'GET') {
            return response(jsonEncode([recipe.toJson()]), 200);
          }
          final payload = jsonDecode(r.body) as Map<String, dynamic>;
          expect(payload.containsKey('favorite'), false);
          expect(payload['image'], isNull);
          return response(jsonEncode(payload), 201);
        }),
      );
      expect((await api.getRecipes()).single.name, 'Canh');
      await api.createRecipe(recipe);
      expect(seen.first.url.toString(), 'https://example.org/api/recipes');
      api.close();
    },
  );
  test('rejects malformed and partially invalid collections', () async {
    for (final body in ['{}', '[{"id":"bad"}]', '[false]', 'not json']) {
      final api = RecipeApi(
        baseUrl: 'https://example.org',
        client: MockClient((_) async => response(body, 200)),
      );
      await expectLater(
        api.getRecipes(),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.invalidData,
          ),
        ),
      );
      api.close();
    }
  });
  test('maps HTTP errors and missing record distinctly', () async {
    final api = RecipeApi(
      baseUrl: 'https://example.org',
      client: MockClient((_) async => response('{}', 404)),
    );
    expect(await api.getRecipe('missing'), isNull);
    await expectLater(
      api.getIngredients(),
      throwsA(isA<AppFailure>().having((e) => e.statusCode, 'status', 404)),
    );
  });
  test('maps network and total request timeout without retrying', () async {
    var calls = 0;
    final api = RecipeApi(
      baseUrl: 'https://example.org',
      timeout: const Duration(milliseconds: 5),
      client: MockClient((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return response('[]', 200);
      }),
    );
    await expectLater(
      api.getRecipes(),
      throwsA(
        isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.timeout),
      ),
    );
    expect(calls, 1);
    final offline = RecipeApi(
      baseUrl: 'https://example.org',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      offline.getRecipes(),
      throwsA(
        isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.network),
      ),
    );
  });
  test(
    'deadline includes a response body that never finishes promptly',
    () async {
      final api = RecipeApi(
        baseUrl: 'https://example.org',
        timeout: const Duration(milliseconds: 5),
        client: SlowBodyClient(),
      );
      await expectLater(
        api.getRecipes(),
        throwsA(
          isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.timeout),
        ),
      );
    },
  );
  test('rejects write acknowledgement for a different record ID', () async {
    final api = RecipeApi(
      baseUrl: 'https://example.org',
      client: MockClient(
        (_) async =>
            response(jsonEncode(recipe.copy(id: 'wrong').toJson()), 201),
      ),
    );
    await expectLater(
      api.createRecipe(recipe),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.kind,
          'kind',
          FailureKind.invalidData,
        ),
      ),
    );
  });
  test(
    'uses REST collection and item methods and accepts empty delete ACK',
    () async {
      final calls = <String>[];
      const item = Ingredient(id: 'i1', name: 'Rau');
      final api = RecipeApi(
        baseUrl: 'https://example.org',
        client: MockClient((r) async {
          calls.add('${r.method} ${r.url.path}');
          expect(r.headers['accept'], 'application/json');
          if (r.method == 'DELETE') {
            return response('', 204);
          }
          if (r.method != 'GET') {
            expect(r.headers['content-type'], contains('application/json'));
            return response(r.body, r.method == 'POST' ? 201 : 200);
          }
          if (r.url.path == '/ingredients') {
            return response(jsonEncode([item.toJson()]), 200);
          }
          return response(jsonEncode(item.toJson()), 200);
        }),
      );
      expect((await api.getIngredients()).single.id, 'i1');
      expect((await api.getIngredient('i1'))!.name, 'Rau');
      expect((await api.createIngredient(item)).id, 'i1');
      expect((await api.updateIngredient(item)).id, 'i1');
      expect(
        (await api.updateRecipe(
          recipe.copy(image: 'https://example.org/food.jpg'),
        )).image,
        'https://example.org/food.jpg',
      );
      await api.deleteRecipe('r1');
      expect(calls, [
        'GET /ingredients',
        'GET /ingredients/i1',
        'POST /ingredients',
        'PUT /ingredients/i1',
        'PUT /recipes/r1',
        'DELETE /recipes/r1',
      ]);
      api.close();
    },
  );
}

class SlowBodyClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream<List<int>>.fromFuture(
          Future<List<int>>.delayed(
            const Duration(milliseconds: 20),
            () => utf8.encode('[]'),
          ),
        ),
        200,
      );
}
