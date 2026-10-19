import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app_controller.dart';
import '../domain/engine.dart';
import 'shared.dart';

class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});
  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  bool loading = false;
  String? error;
  List<Suggestion>? ai;
  String? resultScope;
  String? resultBook;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    // Do not retain another user's AI results or stale results after edits.
    if (resultScope != null &&
        (resultScope != app.scope || resultBook != app.book.encode())) {
      ai = null;
      error = null;
      resultScope = null;
    }
    final rules = suggest(
      app.allRecipes,
      app.book.pantry,
      app.book.preferences,
      DateTime.now(),
    ).take(10).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hôm nay nấu gì?'),
        actions: [
          IconButton(
            tooltip: 'Sở thích ăn uống',
            onPressed: () => context.push('/account'),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Theo khẩu vị của bạn',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tối đa ${app.book.preferences.maxMinutes} phút • ${app.book.preferences.servings} người'
            '${app.book.preferences.vegetarian ? ' • Món chay' : ''}',
          ),
          const SectionTitle('Gợi ý AI'),
          const Text(
            'AI chọn món từ thư viện, cân nhắc nguyên liệu và sở thích. Bạn quyết định món nào vào thực đơn.',
          ),
          const SizedBox(height: 12),
          if (!app.signedIn)
            OutlinedButton.icon(
              onPressed: () => context.push('/account'),
              icon: const Icon(Icons.login),
              label: const Text('Đăng nhập để dùng AI'),
            )
          else
            FilledButton.icon(
              onPressed: loading || !app.ready || app.offline
                  ? null
                  : () async {
                      setState(() {
                        loading = true;
                        error = null;
                        ai = null;
                      });
                      final scope = app.scope;
                      final snapshot = app.book.encode();
                      try {
                        final results = await app.aiSuggestions();
                        if (mounted &&
                            scope == app.scope &&
                            snapshot == app.book.encode()) {
                          setState(() {
                            ai = results;
                            resultScope = scope;
                            resultBook = snapshot;
                          });
                        }
                      } catch (_) {
                        if (mounted && scope == app.scope) {
                          setState(
                            () => error =
                                'Gợi ý AI hiện không khả dụng. Vui lòng thử lại sau.',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => loading = false);
                      }
                    },
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                loading
                    ? 'Đang chọn món…'
                    : error == null
                    ? 'Nhờ AI gợi ý món'
                    : 'Thử lại gợi ý AI',
              ),
            ),
          if (error != null)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(error!),
              ),
            ),
          if (ai != null && ai!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Chưa có công thức phù hợp với bộ lọc của bạn.'),
            ),
          ...?ai?.map((s) => _suggestion(context, app, s)),
          const SectionTitle('Gợi ý theo nguyên liệu'),
          const Text(
            'Hoạt động độc lập với AI. Ưu tiên món có nguyên liệu sẵn và sắp hết hạn; không bảo đảm đủ toàn bộ lượng cần nấu.',
          ),
          const SizedBox(height: 16),
          if (rules.isEmpty)
            const EmptyState(
              title: 'Chưa có món phù hợp',
              description: 'Thử tăng thời gian nấu hoặc cập nhật sở thích.',
            ),
          ...rules.map((s) => _suggestion(context, app, s)),
        ],
      ),
    );
  }

  Widget _suggestion(BuildContext context, AppController app, Suggestion s) =>
      Column(
        children: [
          RecipeTile(
            s.recipe,
            subtitle: s.reason,
            onTap: () => context.push('/recipe/${s.recipe.id}'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: app.canEdit
                  ? () => addMealDialog(context, app, s.recipe)
                  : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm vào thực đơn'),
            ),
          ),
        ],
      );
}
