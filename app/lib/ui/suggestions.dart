import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_controller.dart';
import '../domain/engine.dart';
import '../domain/load_state.dart';
import 'shared.dart';

class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});
  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
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
            onPressed: () => context.push('/settings'),
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
          CatalogStatus(app: app),
          const SectionTitle('Gợi ý theo nguyên liệu'),
          const Text(
            'Ưu tiên món có nguyên liệu sẵn và sắp hết hạn; không bảo đảm đủ toàn bộ lượng cần nấu.',
          ),
          const SizedBox(height: 16),
          if (rules.isEmpty &&
              app.catalogState.status != LoadStatus.loading &&
              app.catalogState.status != LoadStatus.error)
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
