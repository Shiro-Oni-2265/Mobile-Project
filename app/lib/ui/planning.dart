import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../domain/engine.dart';
import '../domain/models.dart';
import '../domain/load_state.dart';
import 'shared.dart';

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});
  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final meals = app.book.meals
        .where((m) => m.date == dayKey(selected))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionTitle(
          'Thực đơn tuần',
          action: TextButton(
            onPressed: () =>
                setState(() => selected = DateUtils.dateOnly(DateTime.now())),
            child: const Text('Hôm nay'),
          ),
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Tuần trước',
              onPressed: () => setState(
                () => selected = selected.subtract(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${DateFormat('dd/MM').format(monday)} – ${DateFormat('dd/MM/yyyy').format(monday.add(const Duration(days: 6)))}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Tuần sau',
              onPressed: () => setState(
                () => selected = selected.add(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: List.generate(7, (i) {
            final day = monday.add(Duration(days: i));
            final active = dayKey(day) == dayKey(selected);
            final hasMeal = app.book.meals.any((m) => m.date == dayKey(day));
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => selected = day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          i == 6 ? 'CN' : 'T${i + 2}',
                          style: TextStyle(
                            fontSize: 11,
                            color: active ? Colors.white70 : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: active ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.circle,
                          size: 4,
                          color: hasMeal
                              ? (active
                                    ? Colors.white
                                    : const Color(0xFF386B4E))
                              : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        for (final meal in ['Sáng', 'Trưa', 'Tối']) ...[
          SectionTitle(
            'Bữa ${meal.toLowerCase()}',
            action: TextButton.icon(
              onPressed: app.canEdit ? () => _choose(context, app, meal) : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm món'),
            ),
          ),
          if (!meals.any((m) => m.meal == meal))
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Chưa có món • Thêm một món bạn thích',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ...meals
              .where((m) => m.meal == meal)
              .map(
                (m) => Card(
                  child: ListTile(
                    title: Text(m.recipe.name),
                    subtitle: Text(
                      '${m.servings} người • ${m.recipe.minutes} phút',
                    ),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(m.recipe.name),
                        content: SizedBox(
                          width: 400,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...m.recipe.items.map(
                                  (i) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '${app.ingredientName(i.ingredientId)}: ${quantity(i.amount == null ? null : i.amount! * m.servings / m.recipe.servings)} ${i.amount == null ? '' : i.unit}',
                                    ),
                                  ),
                                ),
                                const Divider(),
                                ...m.recipe.steps.asMap().entries.map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text('${e.key + 1}. ${e.value}'),
                                  ),
                                ),
                              ],
                            ),
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
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) => _modify(context, app, m, action),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          enabled: app.canEdit,
                          child: const Text('Đổi ngày / bữa / khẩu phần'),
                        ),
                        PopupMenuItem(
                          value: 'replace',
                          enabled: app.canEdit,
                          child: const Text('Thay món'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          enabled: app.canEdit,
                          child: const Text('Bỏ món'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          if (meals.any((m) => m.meal == meal))
            NutritionCard(
              dayNutrition(
                meals.where((m) => m.meal == meal).toList(),
                app.catalog,
              ),
              title:
                  'Dinh dưỡng bữa ${meal.toLowerCase()} • tổng các khẩu phần',
            ),
        ],
        if (meals.isNotEmpty) ...[
          const SizedBox(height: 16),
          NutritionCard(
            dayNutrition(meals, app.catalog),
            title: 'Tổng dinh dưỡng ngày • tất cả khẩu phần',
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Tổng cho các món và khẩu phần đã xếp, không mặc định là lượng ăn của một người.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Future<Recipe?> _pick(BuildContext context, AppController app) async {
    var search = '';
    return showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Consumer(
        builder: (context, ref, child) {
          final current = ref.watch(appProvider);
          return StatefulBuilder(
            builder: (context, setState) {
              final results = current.allRecipes
                  .where(
                    (r) => r.name.toLowerCase().contains(search.toLowerCase()),
                  )
                  .toList();
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .7,
                  child: Column(
                    children: [
                      CatalogStatus(app: current),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Tìm công thức',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => search = v),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          children: [
                            ...results.map(
                              (r) => RecipeTile(
                                r,
                                onTap: () => Navigator.pop(context, r),
                              ),
                            ),
                            if (results.isEmpty &&
                                current.catalogState.status !=
                                    LoadStatus.loading &&
                                current.catalogState.status != LoadStatus.error)
                              EmptyState(
                                title: current.allRecipes.isEmpty
                                    ? 'Thư viện chưa có công thức'
                                    : 'Chưa tìm thấy món',
                                description:
                                    'Tải lại thư viện, thêm công thức hoặc đổi từ khóa.',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _choose(
    BuildContext context,
    AppController app,
    String meal,
  ) async {
    final r = await _pick(context, app);
    if (r == null || !context.mounted) return;
    // Dialog explicitly chooses meal; default is passed to match the selected section.
    await addMealDialog(context, app, r, date: selected, initialMeal: meal);
  }

  Future<void> _modify(
    BuildContext context,
    AppController app,
    MealEntry entry,
    String action,
  ) async {
    if (action == 'delete') {
      if (await confirm(context, 'Bỏ món khỏi thực đơn?', entry.recipe.name) &&
          context.mounted) {
        await perform(
          context,
          () => app.save(
            app.book.copy(
              meals: app.book.meals.where((m) => m.id != entry.id).toList(),
            ),
          ),
        );
      }
      return;
    }
    Recipe recipe = entry.recipe;
    if (action == 'replace') {
      final replacement = await _pick(context, app);
      if (replacement == null) return;
      recipe = replacement;
    }
    if (!context.mounted) return;
    var day = DateTime.parse(entry.date),
        meal = entry.meal,
        count = entry.servings;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(recipe.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: day,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => day = d);
                },
                child: Text(dayKey(day)),
              ),
              DropdownButton<String>(
                value: meal,
                items: ['Sáng', 'Trưa', 'Tối']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => meal = v!),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: count > 1 ? () => setState(() => count--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$count người'),
                  IconButton(
                    onPressed: count < 30
                        ? () => setState(() => count++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (result == true && context.mounted) {
      final next = MealEntry(
        id: entry.id,
        date: dayKey(day),
        meal: meal,
        servings: count,
        recipe: recipe,
      );
      await perform(
        context,
        () => app.save(
          app.book.copy(
            meals: app.book.meals
                .map((m) => m.id == entry.id ? next : m)
                .toList(),
          ),
        ),
      );
    }
  }
}
