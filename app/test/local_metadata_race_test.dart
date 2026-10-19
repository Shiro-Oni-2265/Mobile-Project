import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:naugi/domain/models.dart';

import 'support.dart';

class GatedMetadataStore extends MemoryStore {
  final started = Completer<void>();
  final release = Completer<void>();
  bool holdNextWrite = true;

  @override
  Future<void> write(String scope, Notebook notebook) async {
    if (holdNextWrite) {
      holdNextWrite = false;
      started.complete();
      await release.future;
    }
    await super.write(scope, notebook);
  }
}

void main() {
  for (final metadata in ['favorite', 'photo']) {
    test('queued $metadata survives a stale local notebook save', () async {
      final store = GatedMetadataStore();
      store.data['guest'] = const Notebook();
      final server = TestApiServer()..offline = true;
      final repository = server.repository(store);
      addTearDown(repository.api.close);
      await repository.initialize();

      final metadataWrite = metadata == 'favorite'
          ? repository.toggleFavorite('recipe-1')
          : repository.setLocalImage('recipe-1', '/local/photo.jpg');
      await store.started.future;

      // The UI can start another local action while the first disk write waits.
      // Its snapshot has not yet observed the pending favorite/photo change.
      final stale = repository.book;
      expect(stale.favoriteIds, isEmpty);
      expect(stale.localImages, isEmpty);
      final localWrite = repository.saveLocal(
        stale.copy(preferences: const Preferences(servings: 7)),
      );
      store.release.complete();
      await Future.wait([metadataWrite, localWrite]);

      final restored = server.repository(store);
      addTearDown(restored.api.close);
      await restored.initialize();
      for (final notebook in [repository.book, restored.book]) {
        expect(notebook.preferences.servings, 7);
        if (metadata == 'favorite') {
          expect(notebook.favoriteIds, contains('recipe-1'));
        } else {
          expect(notebook.localImages['recipe-1'], '/local/photo.jpg');
        }
      }
    });
  }
}
