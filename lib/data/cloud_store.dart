import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models.dart';

class CloudSnapshot {
  final Notebook notebook;
  final int revision;
  const CloudSnapshot(this.notebook, this.revision);
}

abstract class CloudStore {
  Future<CloudSnapshot> read();
  Future<int> write(Notebook notebook, int revision);
}

class SupabaseStore implements CloudStore {
  final SupabaseClient client;
  SupabaseStore(this.client);
  @override
  Future<CloudSnapshot> read() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Bạn cần đăng nhập lại.');
    final row = await client
        .from('notebooks')
        .select('payload, revision')
        .eq('user_id', user.id)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    if (row == null) return const CloudSnapshot(Notebook(), 0);
    return CloudSnapshot(
      Notebook.fromJson(Map<String, dynamic>.from(row['payload'])),
      row['revision'] as int,
    );
  }

  @override
  Future<int> write(Notebook notebook, int revision) async {
    final result = await client
        .rpc(
          'save_notebook',
          params: {
            'document': notebook.toJson(),
            'expected_revision': revision,
          },
        )
        .timeout(const Duration(seconds: 15));
    return result as int;
  }
}
