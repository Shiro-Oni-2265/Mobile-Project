import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:naugi/app_controller.dart';
import 'package:naugi/data/catalog.dart';
import 'package:naugi/data/cloud_store.dart';
import 'package:naugi/domain/engine.dart';
import 'package:naugi/domain/models.dart';
import 'support.dart';

const uid = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';

class FakeCloud implements CloudStore {
  Notebook document = const Notebook();
  int revision = 0;
  bool failRead = false, failWrite = false;
  @override
  Future<CloudSnapshot> read() async {
    if (failRead) throw StateError('offline');
    return CloudSnapshot(document, revision);
  }

  @override
  Future<int> write(Notebook notebook, int expected) async {
    if (failWrite || expected != revision) throw StateError('conflict');
    document = notebook;
    return ++revision;
  }
}

Future<SupabaseClient> signedClient({int aiStatus = 503}) async {
  final client = SupabaseClient(
    'https://test.supabase.co',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/token')) {
        final expiry =
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;
        String b64(Object object) => base64Url
            .encode(utf8.encode(jsonEncode(object)))
            .replaceAll('=', '');
        final token =
            '${b64({'alg': 'HS256'})}.${b64({'sub': uid, 'exp': expiry, 'role': 'authenticated'})}.test';
        return http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'refresh',
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': {
              'id': uid,
              'aud': 'authenticated',
              'email': 'test@example.com',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-10-19T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.contains('/functions/')) {
        return http.Response(
          jsonEncode(
            aiStatus == 200
                ? {
                    'suggestions': [
                      {'id': 'invented', 'reason': 'x'},
                    ],
                  }
                : {'error': 'AI_UNAVAILABLE'},
          ),
          aiStatus,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  await client.auth.signInWithPassword(
    email: 'test@example.com',
    password: 'password123',
  );
  return client;
}

void main() {
  test('account offline loads only its own cache and blocks edits', () async {
    final local = MemoryStore();
    local.data['account:$uid'] = Notebook(
      recipes: [sampleRecipes.first.copy(id: 'account')],
    );
    local.data['guest'] = Notebook(
      recipes: [sampleRecipes.last.copy(id: 'guest')],
    );
    final client = await signedClient();
    final cloud = FakeCloud()..failRead = true;
    final app = AppController(local: local, client: client, cloud: cloud);
    await app.loadAccount();
    expect(app.offline, true);
    expect(app.canEdit, false);
    expect(app.book.recipes.single.id, 'account');
    await expectLater(app.save(const Notebook()), throwsStateError);
    app.dispose();
    await client.dispose();
  });
  test(
    'conflicting account save preserves book and requires refresh',
    () async {
      final client = await signedClient();
      final cloud = FakeCloud();
      final app = AppController(
        local: MemoryStore(),
        client: client,
        cloud: cloud,
      );
      await app.loadAccount();
      cloud.revision = 1;
      await expectLater(
        app.saveRecipe(sampleRecipes.first.copy(id: 'mine')),
        throwsStateError,
      );
      expect(app.book.recipes, isEmpty);
      expect(app.offline, true);
      await app.loadAccount();
      expect(app.canEdit, true);
      expect(app.revision, 1);
      app.dispose();
      await client.dispose();
    },
  );
  test(
    'guest import failure retains local data; success transfers once',
    () async {
      final local = MemoryStore();
      local.data['guest'] = Notebook(
        recipes: [sampleRecipes.first.copy(id: 'mine', sample: false)],
        preferences: const Preferences(vegetarian: true),
      );
      final client = await signedClient();
      final cloud = FakeCloud();
      final app = AppController(local: local, client: client, cloud: cloud);
      await app.loadAccount();
      cloud.failWrite = true;
      await expectLater(app.importGuest(), throwsStateError);
      expect(local.data.containsKey('guest'), true);
      cloud.failWrite = false;
      await app.loadAccount();
      await app.importGuest();
      expect(local.data.containsKey('guest'), false);
      expect(cloud.document.recipes.single.id, 'mine');
      expect(cloud.document.preferences.vegetarian, true);
      await app.importGuest();
      expect(cloud.document.recipes.length, 1);
      app.dispose();
      await client.dispose();
    },
  );
  test(
    'AI provider error leaves independent suggestions and notebook untouched',
    () async {
      final client = await signedClient();
      final app = AppController(
        local: MemoryStore(),
        client: client,
        cloud: FakeCloud(),
      );
      await app.loadAccount();
      final before = app.book.encode();
      await expectLater(
        app.aiSuggestions(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('không khả dụng'),
          ),
        ),
      );
      expect(app.book.encode(), before);
      expect(
        suggest(app.allRecipes, [], app.book.preferences, DateTime.now()),
        isNotEmpty,
      );
      expect(app.canEdit, true);
      app.dispose();
      await client.dispose();
    },
  );
  test(
    'AI invented IDs are rejected even when provider reports success',
    () async {
      final client = await signedClient(aiStatus: 200);
      final app = AppController(
        local: MemoryStore(),
        client: client,
        cloud: FakeCloud(),
      );
      await app.loadAccount();
      await expectLater(app.aiSuggestions(), throwsStateError);
      app.dispose();
      await client.dispose();
    },
  );
}
