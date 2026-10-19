import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_controller.dart';
import '../domain/engine.dart';
import '../domain/models.dart';
import '../domain/load_state.dart';
import 'pantry.dart';
import 'shared.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});
  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  String search = '', filter = 'Tất cả', category = 'Tất cả';
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final results = app.allRecipes
        .where(
          (r) =>
              r.name.toLowerCase().contains(search.toLowerCase()) &&
              (filter != 'Yêu thích' || r.favorite) &&
              (filter != 'Tự tạo' || !r.sample) &&
              (filter != 'Món mẫu' || r.sample) &&
              (category == 'Tất cả' || r.category == category),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: app.refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CatalogStatus(app: app),
          SectionTitle(
            'Sổ tay công thức',
            action: IconButton.filled(
              onPressed: app.canWriteRemote
                  ? () => context.push('/recipe/new')
                  : null,
              tooltip: 'Tạo công thức',
              icon: const Icon(Icons.add),
            ),
          ),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Tìm món bạn muốn nấu…',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => search = v),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final value in [
                  'Tất cả',
                  'Tự tạo',
                  'Yêu thích',
                  'Món mẫu',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(value),
                      selected: filter == value,
                      onSelected: (_) => setState(() => filter = value),
                    ),
                  ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: category,
            isExpanded: true,
            items: [
              'Tất cả',
              'Món chính',
              'Món canh',
              'Món rau',
              'Ăn sáng',
              'Khác',
            ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => category = v!),
          ),
          const SizedBox(height: 12),
          ...results.map(
            (r) => RecipeTile(r, onTap: () => context.push('/recipe/${r.id}')),
          ),
          if (results.isEmpty &&
              app.catalogState.status != LoadStatus.loading &&
              app.catalogState.status != LoadStatus.error)
            EmptyState(
              title: app.allRecipes.isEmpty
                  ? 'Thư viện chưa có công thức'
                  : 'Chưa tìm thấy món',
              description:
                  'Đổi bộ lọc, tìm bằng từ khác hoặc tạo công thức của bạn.',
            ),
        ],
      ),
    );
  }
}

class RecipeScreen extends ConsumerStatefulWidget {
  final String id;
  const RecipeScreen({super.key, required this.id});
  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  int? servings;
  final completed = <int>{};
  final String copyId = uuid.v4();
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final matches = app.allRecipes.where((r) => r.id == widget.id);
    if (matches.isEmpty) {
      final waiting =
          app.catalogState.status == LoadStatus.loading ||
          app.catalogState.status == LoadStatus.error;
      return Scaffold(
        appBar: AppBar(),
        body: ListView(
          children: [
            CatalogStatus(app: app),
            if (!waiting)
              EmptyState(
                title: 'Không tìm thấy công thức',
                description: 'Công thức có thể đã bị xóa.',
                action: TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Về thư viện'),
                ),
              ),
          ],
        ),
      );
    }
    final r = matches.first;
    final count = servings ?? r.servings;
    final whole = nutrition(r, app.catalog, servings: count);
    final perPerson = NutritionResult(
      whole.total.scale(1 / count),
      whole.missing,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(r.name),
        actions: [
          IconButton(
            tooltip: r.sample ? 'Lưu vào yêu thích của tôi' : 'Yêu thích',
            onPressed: app.canEdit
                ? () => perform(context, () => app.favorite(r))
                : null,
            icon: Icon(r.favorite ? Icons.favorite : Icons.favorite_border),
          ),
          if (!r.sample)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') context.push('/recipe/${r.id}/edit');
                if (value == 'delete' &&
                    await confirm(
                      context,
                      'Xóa công thức?',
                      'Món trong thực đơn đã lưu vẫn được giữ nguyên.',
                    )) {
                  if (!context.mounted) return;
                  final ok = await perform(
                    context,
                    () => app.removeRecipe(r.id),
                  );
                  if (ok && context.mounted) context.pop();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  enabled: app.canWriteRemote,
                  child: const Text('Chỉnh sửa'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: app.canWriteRemote,
                  child: const Text('Xóa công thức'),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CatalogStatus(app: app),
          RecipeArt(r, height: 220),
          OutlinedButton.icon(
            onPressed: app.canEdit
                ? () => perform(context, () => app.changeRecipePhoto(r.id))
                : null,
            icon: const Icon(Icons.photo_outlined),
            label: const Text('Đổi ảnh trên thiết bị'),
          ),
          if (app.book.localImages.containsKey(r.id))
            TextButton(
              onPressed: app.canEdit
                  ? () => perform(context, () => app.setRecipeImage(r.id, null))
                  : null,
              child: const Text('Bỏ ảnh trên thiết bị'),
            ),
          const SizedBox(height: 20),
          Text(
            r.name,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${r.minutes} phút • ${r.category}${r.vegetarian ? ' • Món chay' : ''}',
          ),
          const SizedBox(height: 8),
          Text(r.description),
          if (r.sample)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Tạo bản sao trên thư viện'),
                onPressed: !app.canWriteRemote
                    ? null
                    : () async {
                        final copy = r.copy(id: copyId, sample: false);
                        final ok = await perform(
                          context,
                          () => app.saveRecipe(copy),
                        );
                        if (ok && context.mounted) {
                          context.pushReplacement('/recipe/${copy.id}');
                        }
                      },
              ),
            ),
          const SectionTitle('Nguyên liệu'),
          Row(
            children: [
              const Expanded(child: Text('Khẩu phần')),
              IconButton(
                onPressed: count > 1
                    ? () => setState(() => servings = count - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$count người'),
              IconButton(
                onPressed: count < 30
                    ? () => setState(() => servings = count + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          ...r.items.map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.circle, size: 7),
              title: Text(app.ingredientName(i.ingredientId)),
              trailing: Text(
                i.amount == null
                    ? 'Vừa đủ'
                    : '${quantity(i.amount! * count / r.servings)} ${i.unit}',
              ),
            ),
          ),
          NutritionCard(whole, title: 'Cả món • $count người'),
          NutritionCard(perPerson, title: 'Mỗi khẩu phần'),
          const SectionTitle('Cùng vào bếp'),
          ...r.steps.asMap().entries.map(
            (e) => Card(
              child: CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                value: completed.contains(e.key),
                onChanged: (v) => setState(() {
                  v! ? completed.add(e.key) : completed.remove(e.key);
                }),
                title: Text(
                  'Bước ${e.key + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(e.value),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: app.canEdit
                ? () => addMealDialog(context, app, r)
                : null,
            icon: const Icon(Icons.calendar_month),
            label: const Text('Thêm vào thực đơn'),
          ),
        ],
      ),
    );
  }
}

class RecipeEditor extends ConsumerStatefulWidget {
  final String? id;
  const RecipeEditor({super.key, this.id});
  @override
  ConsumerState<RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends ConsumerState<RecipeEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      description = TextEditingController(),
      minutes = TextEditingController(text: '20'),
      servings = TextEditingController(text: '2'),
      steps = TextEditingController();
  List<RecipeItem> items = [];
  String category = 'Món chính';
  String? image;
  bool vegetarian = false, favorite = false, loading = false;
  late final String id;
  bool hydrated = false;
  @override
  void initState() {
    super.initState();
    id = widget.id ?? uuid.v4();
  }

  void hydrate(Recipe r) {
    if (hydrated) return;
    hydrated = true;
    name.text = r.name;
    description.text = r.description;
    minutes.text = '${r.minutes}';
    servings.text = '${r.servings}';
    steps.text = r.steps.join('\n\n');
    items = List.of(r.items);
    category = r.category;
    image = r.image;
    vegetarian = r.vegetarian;
    favorite = r.favorite;
  }

  @override
  void dispose() {
    for (final c in [name, description, minutes, servings, steps]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    if (widget.id != null) {
      final matches = app.allRecipes.where((r) => r.id == widget.id);
      if (matches.isEmpty || matches.first.sample) {
        final waiting =
            matches.isEmpty &&
            (app.catalogState.status == LoadStatus.loading ||
                app.catalogState.status == LoadStatus.error);
        return Scaffold(
          appBar: AppBar(title: const Text('Sửa công thức')),
          body: ListView(
            children: [
              CatalogStatus(app: app),
              if (!waiting)
                EmptyState(
                  title: matches.isEmpty
                      ? 'Không tìm thấy công thức'
                      : 'Công thức mẫu chỉ được xem',
                  description: 'Mở chi tiết và tạo bản sao để chỉnh sửa.',
                  action: TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Về thư viện'),
                  ),
                ),
            ],
          ),
        );
      }
      hydrate(matches.first);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'Công thức mới' : 'Sửa công thức'),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: name,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Tên món'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nhập tên món' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: description,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Mô tả & ghi chú'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: minutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tổng thời gian (phút)',
                    ),
                    validator: (v) => _positive(v, 1440),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: servings,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Số người'),
                    validator: (v) => _positive(v, 30),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Danh mục'),
              items: [
                'Món chính',
                'Món canh',
                'Món rau',
                'Ăn sáng',
                'Khác',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => category = v!,
            ),
            SwitchListTile(
              title: const Text('Món chay'),
              value: vegetarian,
              onChanged: (v) => setState(() => vegetarian = v),
            ),
            OutlinedButton.icon(
              onPressed: loading
                  ? null
                  : () async {
                      await perform(context, () async {
                        final path = await app.pickRecipeImage();
                        if (path != null && mounted) {
                          setState(() => image = path);
                        }
                      });
                    },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                image == null ? 'Chọn ảnh món ăn' : 'Đã chọn ảnh • Chọn lại',
              ),
            ),
            if (image != null)
              TextButton(
                onPressed: () => setState(() => image = null),
                child: const Text('Bỏ ảnh'),
              ),
            CatalogStatus(app: app),
            SectionTitle(
              'Nguyên liệu',
              action: TextButton.icon(
                onPressed: () async {
                  final item = await ingredientAmountDialog(context, app);
                  if (item != null) setState(() => items.add(item));
                },
                icon: const Icon(Icons.add),
                label: const Text('Thêm'),
              ),
            ),
            ...items.asMap().entries.map(
              (e) => Card(
                child: ListTile(
                  title: Text(app.ingredientName(e.value.ingredientId)),
                  subtitle: Text(
                    '${quantity(e.value.amount)} ${e.value.amount == null ? '' : e.value.unit}',
                  ),
                  onTap: () async {
                    final edited = await ingredientAmountDialog(
                      context,
                      app,
                      existing: e.value,
                    );
                    if (edited != null) setState(() => items[e.key] = edited);
                  },
                  trailing: IconButton(
                    tooltip: 'Bỏ nguyên liệu',
                    onPressed: () => setState(() => items.removeAt(e.key)),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/ingredients'),
              child: const Text('Thêm nguyên liệu mới / dữ liệu dinh dưỡng'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: steps,
              minLines: 6,
              maxLines: 15,
              decoration: const InputDecoration(
                labelText: 'Các bước thực hiện',
                hintText: 'Mỗi bước cách nhau một dòng trống',
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Nhập ít nhất một bước'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: loading || !app.canWriteRemote
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      if (items.isEmpty) {
                        message(context, 'Thêm ít nhất một nguyên liệu.');
                        return;
                      }
                      setState(() => loading = true);
                      final r = Recipe(
                        id: id,
                        name: name.text.trim(),
                        description: description.text.trim(),
                        category: category,
                        image: image,
                        minutes: int.parse(minutes.text),
                        servings: int.parse(servings.text),
                        vegetarian: vegetarian,
                        favorite: favorite,
                        items: List.of(items),
                        steps: steps.text
                            .trim()
                            .split(RegExp(r'\n\s*\n'))
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList(),
                      );
                      final ok = await perform(
                        context,
                        () => app.saveRecipe(r),
                      );
                      if (mounted) {
                        setState(() => loading = false);
                        if (ok && context.mounted) context.pop();
                      }
                    },
              child: Text(loading ? 'Đang lưu…' : 'Lưu công thức'),
            ),
          ],
        ),
      ),
    );
  }

  String? _positive(String? v, int max) {
    final n = int.tryParse(v ?? '');
    return n == null || n < 1 || n > max ? 'Nhập số từ 1 đến $max' : null;
  }
}
