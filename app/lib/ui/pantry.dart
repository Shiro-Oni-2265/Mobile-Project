import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_controller.dart';
import '../domain/models.dart';
import '../domain/load_state.dart';
import 'shared.dart';

const units = ['g', 'kg', 'ml', 'l', 'quả', 'cái', 'bó', 'muỗng'];

Future<RecipeItem?> ingredientAmountDialog(
  BuildContext context,
  AppController app, {
  RecipeItem? existing,
  bool allowUnquantified = true,
}) async {
  if (app.catalog.isEmpty && existing == null) {
    message(
      context,
      'Chưa có nguyên liệu. Tải lại danh mục hoặc thêm nguyên liệu mới.',
    );
    return null;
  }
  var ingredient = existing?.ingredientId ?? app.catalog.keys.first;
  var unit = existing?.unit ?? 'g';
  var unquantified = existing != null && existing.amount == null;
  final amount = TextEditingController(
    text: existing?.amount?.toString() ?? '',
  );
  final form = GlobalKey<FormState>();
  final result = await showDialog<RecipeItem>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? 'Thêm nguyên liệu' : 'Sửa nguyên liệu'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: ingredient,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Nguyên liệu'),
                    items:
                        app.catalog.values
                            .map(
                              (i) => DropdownMenuItem(
                                value: i.id,
                                child: Text(i.name),
                              ),
                            )
                            .toList()
                          ..addAll([
                            if (!app.catalog.containsKey(ingredient))
                              DropdownMenuItem(
                                value: ingredient,
                                child: Text(
                                  '$ingredient (không còn trong danh mục)',
                                ),
                              ),
                          ]),
                    onChanged: (v) => ingredient = v!,
                  ),
                  const SizedBox(height: 16),
                  if (allowUnquantified)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Lượng vừa đủ'),
                      value: unquantified,
                      onChanged: (v) => setState(() => unquantified = v),
                    ),
                  if (!unquantified) ...[
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Số lượng'),
                      validator: positiveAmount,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: unit,
                      decoration: const InputDecoration(labelText: 'Đơn vị'),
                      items: {...units, unit}
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (v) => unit = v!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              Navigator.pop(
                context,
                RecipeItem(
                  ingredient,
                  unquantified ? null : parseAmount(amount.text),
                  unit,
                ),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    ),
  );
  // Wait until route transition has detached its text field before disposal.
  Future<void>.delayed(const Duration(milliseconds: 400), amount.dispose);
  return result;
}

double? parseAmount(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));
String? positiveAmount(String? value) {
  final n = parseAmount(value ?? '');
  return n == null || !n.isFinite || n <= 0 || n > 1000000
      ? 'Nhập số lớn hơn 0, tối đa 1.000.000'
      : null;
}

class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final lots = List<PantryLot>.of(app.book.pantry)
      ..sort((a, b) => a.expiry.compareTo(b.expiry));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tủ lạnh của bạn'),
        actions: [
          IconButton(
            tooltip: 'Danh mục nguyên liệu',
            onPressed: () => context.push('/ingredients'),
            icon: const Icon(Icons.inventory_2_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: app.canEdit ? () => _edit(context, app) : null,
        icon: const Icon(Icons.add),
        label: const Text('Thêm thực phẩm'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          const Text(
            'Theo dõi từng lô và hạn sử dụng. Lượng tồn được bạn cập nhật thủ công.',
          ),
          const SizedBox(height: 16),
          if (lots.isEmpty)
            const EmptyState(
              title: 'Tủ lạnh đang trống',
              description:
                  'Thêm nguyên liệu để gợi ý món và đối chiếu danh sách mua sắm.',
              icon: Icons.kitchen_outlined,
            ),
          ...lots.map((p) {
            final expired = p.expired(DateTime.now());
            final days = DateTime.parse(
              p.expiry,
            ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
            return Card(
              child: ListTile(
                onTap: app.canEdit ? () => _edit(context, app, p) : null,
                leading: CircleAvatar(
                  backgroundColor: expired
                      ? Colors.red.shade50
                      : days <= 2
                      ? Colors.orange.shade50
                      : const Color(0xFFE5EDDF),
                  child: Icon(
                    Icons.eco_outlined,
                    color: expired
                        ? Colors.red
                        : days <= 2
                        ? Colors.orange.shade800
                        : const Color(0xFF386B4E),
                  ),
                ),
                title: Text(app.ingredientName(p.ingredientId)),
                subtitle: Text(
                  '${quantity(p.amount)} ${p.unit}\n${expired ? 'Đã hết hạn' : 'Hạn'}: ${p.expiry}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Xóa lô thực phẩm',
                  onPressed: !app.canEdit
                      ? null
                      : () async {
                          if (await confirm(
                            context,
                            'Xóa thực phẩm?',
                            'Xóa lô ${app.ingredientName(p.ingredientId)} khỏi tủ lạnh.',
                          )) {
                            if (context.mounted) {
                              await perform(
                                context,
                                () => app.save(
                                  app.book.copy(
                                    pantry: app.book.pantry
                                        .where((x) => x.id != p.id)
                                        .toList(),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    AppController app, [
    PantryLot? existing,
  ]) async {
    final item = await ingredientAmountDialog(
      context,
      app,
      allowUnquantified: false,
      existing: existing == null
          ? null
          : RecipeItem(existing.ingredientId, existing.amount, existing.unit),
    );
    if (item == null || !context.mounted) return;
    final expiry = await showDatePicker(
      context: context,
      helpText: 'Chọn hạn sử dụng',
      initialDate: existing == null
          ? DateTime.now().add(const Duration(days: 7))
          : DateTime.parse(existing.expiry),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (expiry == null || !context.mounted) return;
    final lot = PantryLot(
      id: existing?.id ?? uuid.v4(),
      ingredientId: item.ingredientId,
      amount: item.amount!,
      unit: item.unit,
      expiry: dayKey(expiry),
    );
    await perform(
      context,
      () => app.save(
        app.book.copy(
          pantry: [...app.book.pantry.where((p) => p.id != lot.id), lot],
        ),
      ),
    );
  }
}

class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});
  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final ingredients = app.catalog.values
        .where((i) => i.name.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Nguyên liệu & dinh dưỡng')),
      floatingActionButton: FloatingActionButton(
        onPressed: app.canWriteRemote ? () => _edit(context, app) : null,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          CatalogStatus(app: app),
          const Text(
            'Giá trị tham chiếu trên 100 g phần ăn được, nguyên liệu sống. Chạm nguyên liệu để cập nhật theo nguồn của bạn.',
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Tìm nguyên liệu',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => search = v),
          ),
          const SizedBox(height: 12),
          ...ingredients.map(
            (i) => Card(
              child: ListTile(
                title: Text(i.name),
                subtitle: Text(
                  i.per100g == null
                      ? 'Chưa có dữ liệu dinh dưỡng'
                      : '${i.per100g!.kcal.round()} kcal / 100 g • ${i.source ?? 'Người dùng nhập'}',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: app.canWriteRemote ? () => _edit(context, app, i) : null,
              ),
            ),
          ),
          if (ingredients.isEmpty &&
              app.catalogState.status != LoadStatus.loading &&
              app.catalogState.status != LoadStatus.error)
            EmptyState(
              title: app.catalog.isEmpty
                  ? 'Danh mục chưa có nguyên liệu'
                  : 'Không tìm thấy nguyên liệu',
              description: app.catalog.isEmpty
                  ? 'Thêm nguyên liệu mới để bắt đầu.'
                  : 'Thử tìm bằng từ khác hoặc bỏ từ khóa.',
            ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    AppController app, [
    Ingredient? existing,
  ]) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: existing?.name ?? '');
    final source = TextEditingController(
      text: existing?.source ?? 'Người dùng nhập',
    );
    final values = [
      existing?.per100g?.kcal,
      existing?.per100g?.protein,
      existing?.per100g?.carbs,
      existing?.per100g?.fat,
      existing?.gramsPerPiece,
    ].map((v) => TextEditingController(text: v?.toString() ?? '')).toList();
    var hasNutrition = existing?.per100g != null;
    // Keep the same ID if an uncertain request is retried from this form.
    final ingredientId = existing?.id ?? uuid.v4();
    var saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(
              existing == null ? 'Nguyên liệu mới' : 'Sửa nguyên liệu',
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: name,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Tên nguyên liệu',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Nhập tên nguyên liệu';
                          }
                          if (app.catalog.values.any(
                            (i) =>
                                i.id != existing?.id &&
                                i.name.toLowerCase() == v.trim().toLowerCase(),
                          )) {
                            return 'Tên đã có trong danh mục';
                          }
                          return null;
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Có dữ liệu dinh dưỡng'),
                        value: hasNutrition,
                        onChanged: (v) => setState(() => hasNutrition = v),
                      ),
                      if (hasNutrition) ...[
                        for (var index = 0; index < 4; index++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextFormField(
                              controller: values[index],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: [
                                  'Năng lượng (kcal / 100 g)',
                                  'Protein (g / 100 g)',
                                  'Carb (g / 100 g)',
                                  'Chất béo (g / 100 g)',
                                ][index],
                              ),
                              validator: (v) {
                                final n = parseAmount(v ?? '');
                                return n == null ||
                                        !n.isFinite ||
                                        n < 0 ||
                                        n > (index == 0 ? 1000 : 100)
                                    ? 'Nhập giá trị hợp lệ'
                                    : null;
                              },
                            ),
                          ),
                        TextFormField(
                          controller: source,
                          decoration: const InputDecoration(
                            labelText: 'Nguồn dữ liệu',
                          ),
                          maxLength: 200,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Ghi nguồn tham chiếu'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: values[4],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Khối lượng mỗi quả/cái (g)',
                          helperText:
                              'Không bắt buộc; chỉ dùng cho tính dinh dưỡng',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? null
                            : positiveAmount(v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: saving || !app.canWriteRemote
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setState(() => saving = true);
                        final value = Ingredient(
                          id: ingredientId,
                          name: name.text.trim(),
                          per100g: hasNutrition
                              ? Nutrients(
                                  parseAmount(values[0].text)!,
                                  parseAmount(values[1].text)!,
                                  parseAmount(values[2].text)!,
                                  parseAmount(values[3].text)!,
                                )
                              : null,
                          gramsPerPiece: parseAmount(values[4].text),
                          source: hasNutrition ? source.text.trim() : null,
                        );
                        final ok = await perform(
                          context,
                          () => app.saveIngredient(value),
                        );
                        if (!context.mounted) return;
                        setState(() => saving = false);
                        if (ok) Navigator.pop(context);
                      },
                child: Text(saving ? 'Đang lưu…' : 'Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      for (final c in [name, source, ...values]) {
        c.dispose();
      }
    });
  }
}
