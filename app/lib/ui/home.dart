import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../domain/engine.dart';
import '../domain/models.dart';
import '../domain/load_state.dart';
import 'shared.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final now = DateTime.now();
    final meals = app.book.meals.where((m) => m.date == dayKey(now)).toList();
    final soon =
        app.book.pantry
            .where(
              (p) =>
                  DateTime.parse(
                    p.expiry,
                  ).difference(DateTime(now.year, now.month, now.day)).inDays <=
                  2,
            )
            .toList()
          ..sort((a, b) => a.expiry.compareTo(b.expiry));
    final suggestions = suggest(
      app.allRecipes,
      app.book.pantry,
      app.book.preferences,
      now,
    ).take(3).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        CatalogStatus(app: app),
        Text(
          DateFormat('EEEE, dd/MM', 'vi').format(now),
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 6),
        Text(
          'Hôm nay,\nbạn muốn nấu gì?',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF386B4E),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bữa ngon từ những gì sẵn có',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Khám phá món hợp khẩu vị và tận dụng tủ lạnh của bạn.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/suggestions'),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Khám phá gợi ý'),
              ),
            ],
          ),
        ),
        if (soon.isNotEmpty) ...[
          SectionTitle(
            'Dùng sớm nhé',
            action: TextButton(
              onPressed: () => context.push('/pantry'),
              child: const Text('Tủ lạnh'),
            ),
          ),
          ...soon
              .take(3)
              .map(
                (p) => Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.schedule,
                      color: p.expired(now)
                          ? Colors.red
                          : Colors.orange.shade800,
                    ),
                    title: Text(app.ingredientName(p.ingredientId)),
                    subtitle: Text(
                      '${quantity(p.amount)} ${p.unit} • ${p.expired(now) ? 'Đã hết hạn' : 'Hạn'} ${p.expiry}',
                    ),
                  ),
                ),
              ),
        ],
        const SectionTitle('Thực đơn hôm nay'),
        if (meals.isEmpty)
          const EmptyState(
            title: 'Hôm nay chưa có món',
            description: 'Mở Thực đơn hoặc chọn một công thức để thêm món.',
            icon: Icons.calendar_month_outlined,
          ),
        ...meals.map(
          (m) => Card(
            child: ListTile(
              leading: const Icon(Icons.restaurant),
              title: Text(m.recipe.name),
              subtitle: Text(
                'Bữa ${m.meal.toLowerCase()} • ${m.servings} người',
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(m.recipe.name),
                  content: SingleChildScrollView(
                    child: Text(
                      m.recipe.steps
                          .asMap()
                          .entries
                          .map((e) => '${e.key + 1}. ${e.value}')
                          .join('\n\n'),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (meals.isNotEmpty)
          NutritionCard(
            dayNutrition(meals, app.catalog),
            title: 'Dinh dưỡng cả ngày • tổng ${meals.length} món',
          ),
        SectionTitle(
          'Gợi ý theo nguyên liệu',
          action: TextButton(
            onPressed: () => context.push('/suggestions'),
            child: const Text('Xem thêm'),
          ),
        ),
        ...suggestions.map(
          (s) => RecipeTile(
            s.recipe,
            subtitle: s.reason,
            onTap: () => context.push('/recipe/${s.recipe.id}'),
          ),
        ),
        if (suggestions.isEmpty &&
            app.catalogState.status != LoadStatus.loading &&
            app.catalogState.status != LoadStatus.error)
          const Text(
            'Chưa có món phù hợp. Thử điều chỉnh sở thích hoặc bổ sung công thức.',
          ),
      ],
    );
  }
}
