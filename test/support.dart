import 'package:naugi/data/local_store.dart';
import 'package:naugi/domain/models.dart';

class MemoryStore implements NotebookStore {
  final Map<String, Notebook> data = {};
  bool failWrites = false;
  @override
  Future<Notebook?> read(String scope) async => data[scope];
  @override
  Future<void> write(String scope, Notebook notebook) async {
    if (failWrites) throw StateError('Disk full');
    data[scope] = Notebook.fromJson(notebook.toJson());
  }

  @override
  Future<void> remove(String scope) async {
    data.remove(scope);
  }
}
