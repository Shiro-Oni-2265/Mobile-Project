import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/app_failure.dart';
import '../domain/load_state.dart';
import '../app_controller.dart';
import '../domain/engine.dart';
import '../domain/models.dart';

Future<bool> perform(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) message(context, success);
    return true;
  } catch (error) {
    if (context.mounted) message(context, userError(error));
    return false;
  }
}

String userError(Object error) {
  if (error is AppFailure) return error.message;
  if (error is StateError) return error.message.toString();
  return 'Không hoàn tất được thao tác. Kiểm tra kết nối hoặc cấu hình dịch vụ rồi thử lại.';
}

void message(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));
Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ??
    false;

class EmptyState extends StatelessWidget {
  final String title, description;
  final IconData icon;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.ramen_dining,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.center),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 20), child: action!),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionTitle(this.title, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class RecipeArt extends StatelessWidget {
  final Recipe recipe;
  final double height;
  const RecipeArt(this.recipe, {super.key, this.height = 150});
  @override
  Widget build(BuildContext context) {
    final image = recipe.image;
    Widget fallback() => Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: recipe.vegetarian
              ? [const Color(0xFFDDE9CF), const Color(0xFFB8CEAB)]
              : [const Color(0xFFF2E3C9), const Color(0xFFE0B893)],
        ),
      ),
      child: Center(
        child: Icon(
          recipe.category == 'Món canh'
              ? Icons.soup_kitchen
              : recipe.vegetarian
              ? Icons.eco_outlined
              : Icons.ramen_dining,
          size: height * .38,
          color: const Color(0xFF386B4E),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: image == null
          ? fallback()
          : (image.startsWith('https://') || image.startsWith('http://'))
          ? Image.network(
              image,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(),
            )
          : Image.file(
              File(image),
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(),
            ),
    );
  }
}

class RecipeTile extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final String? subtitle;
  const RecipeTile(
    this.recipe, {
    super.key,
    required this.onTap,
    this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(width: 76, child: RecipeArt(recipe, height: 76)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle ??
                        '${recipe.minutes} phút • ${recipe.servings} người • ${recipe.category}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (recipe.sample)
                    const Text(
                      'Công thức mẫu',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
            ),
            if (recipe.favorite)
              const Icon(Icons.favorite, color: Color(0xFFBF7547), size: 20),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    ),
  );
}

class NutritionCard extends StatelessWidget {
  final NutritionResult result;
  final String title;
  const NutritionCard(
    this.result, {
    super.key,
    this.title = 'Dinh dưỡng ước tính',
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              _metric('${result.total.kcal.round()}', 'kcal'),
              _metric(
                '${result.total.protein.toStringAsFixed(1)} g',
                'Protein',
              ),
              _metric('${result.total.carbs.toStringAsFixed(1)} g', 'Carb'),
              _metric('${result.total.fat.toStringAsFixed(1)} g', 'Chất béo'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.complete
                ? 'Ước tính theo nguyên liệu; có thể khác thành phẩm thực tế.'
                : 'Tổng phần đã biết. Thiếu dữ liệu: ${result.missing.join(', ')}.',
            style: TextStyle(
              fontSize: 12,
              color: result.complete
                  ? Colors.grey.shade700
                  : Colors.deepOrange.shade800,
            ),
          ),
        ],
      ),
    ),
  );
  Widget _metric(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

Future<void> addMealDialog(
  BuildContext context,
  AppController app,
  Recipe recipe, {
  DateTime? date,
  String initialMeal = 'Tối',
}) async {
  var selectedDate = date ?? DateTime.now();
  var meal = initialMeal;
  var servings = app.book.preferences.servings;
  await showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Thêm vào thực đơn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(recipe.name),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(dayKey(selectedDate)),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => selectedDate = d);
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: meal,
              decoration: const InputDecoration(labelText: 'Bữa ăn'),
              items: [
                'Sáng',
                'Trưa',
                'Tối',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => meal = v!,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: servings > 1
                      ? () => setState(() => servings--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$servings người'),
                IconButton(
                  onPressed: servings < 30
                      ? () => setState(() => servings++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: app.canEdit
                ? () async {
                    final ok = await perform(
                      context,
                      () => app.addMeal(recipe, selectedDate, meal, servings),
                    );
                    if (ok && context.mounted) Navigator.pop(context);
                  }
                : null,
            child: const Text('Thêm món'),
          ),
        ],
      ),
    ),
  );
}

/// A cache is visible during refresh/error; failure never masquerades as empty.
class CatalogStatus extends StatelessWidget {
  final AppController app;
  const CatalogStatus({super.key, required this.app});
  @override
  Widget build(BuildContext context) {
    final state = app.catalogState;
    if (state.status == LoadStatus.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }
    if (state.status != LoadStatus.error) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.data == null
                  ? 'Chưa tải được thư viện'
                  : 'Đang dùng bản lưu trên thiết bị',
            ),
            Text(state.failure?.message ?? 'Không tải được dữ liệu.'),
            TextButton.icon(
              onPressed: app.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
