import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_controller.dart';
import '../domain/engine.dart';
import '../domain/models.dart';
import 'pantry.dart';
import 'shared.dart';

class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionTitle(
          'Danh sách mua sắm',
          action: IconButton.filled(
            tooltip: 'Tạo danh sách',
            onPressed: app.canEdit ? () => _create(context, app) : null,
            icon: const Icon(Icons.add),
          ),
        ),
        const Text(
          'Từ thực đơn đến giỏ hàng. Tích chọn sau khi mua; chỉnh sửa danh sách độc lập với thực đơn.',
        ),
        const SizedBox(height: 20),
        if (app.book.lists.isEmpty)
          EmptyState(
            title: 'Bạn cần mua những gì?',
            description:
                'Tạo danh sách từ thực đơn hoặc thêm nguyên liệu thủ công.',
            icon: Icons.shopping_basket_outlined,
            action: FilledButton(
              onPressed: app.canEdit ? () => _create(context, app) : null,
              child: const Text('Tạo danh sách'),
            ),
          ),
        ...app.book.lists.reversed.map(
          (list) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      list.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${list.items.where((i) => i.purchased).length}/${list.items.length} đã mua',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'add') {
                          final item = await ingredientAmountDialog(
                            context,
                            app,
                          );
                          if (item != null && context.mounted) {
                            await _save(context, app, list, [
                              ...list.items,
                              ShoppingItem(
                                id: uuid.v4(),
                                ingredientId: item.ingredientId,
                                unit: item.unit,
                                amount: item.amount,
                              ),
                            ]);
                          }
                        } else if (action == 'rename') {
                          final controller = TextEditingController(
                            text: list.name,
                          );
                          final name = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Tên danh sách'),
                              content: TextField(
                                controller: controller,
                                maxLength: 80,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Hủy'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    if (controller.text.trim().isNotEmpty) {
                                      Navigator.pop(
                                        context,
                                        controller.text.trim(),
                                      );
                                    }
                                  },
                                  child: const Text('Lưu'),
                                ),
                              ],
                            ),
                          );
                          if (name != null && context.mounted) {
                            await perform(
                              context,
                              () => app.save(
                                app.book.copy(
                                  lists: app.book.lists
                                      .map(
                                        (l) => l.id == list.id
                                            ? ShoppingList(
                                                id: l.id,
                                                name: name,
                                                items: l.items,
                                              )
                                            : l,
                                      )
                                      .toList(),
                                ),
                              ),
                            );
                          }
                          Future<void>.delayed(
                            const Duration(milliseconds: 400),
                            controller.dispose,
                          );
                        } else if (await confirm(
                              context,
                              'Xóa danh sách?',
                              list.name,
                            ) &&
                            context.mounted) {
                          await perform(
                            context,
                            () => app.save(
                              app.book.copy(
                                lists: app.book.lists
                                    .where((l) => l.id != list.id)
                                    .toList(),
                              ),
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'add',
                          enabled: app.canEdit,
                          child: const Text('Thêm nguyên liệu'),
                        ),
                        PopupMenuItem(
                          value: 'rename',
                          enabled: app.canEdit,
                          child: const Text('Đổi tên'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          enabled: app.canEdit,
                          child: const Text('Xóa danh sách'),
                        ),
                      ],
                    ),
                  ),
                  if (list.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Chưa có mục nào. Dùng menu để thêm nguyên liệu.',
                      ),
                    ),
                  ...list.items.map(
                    (item) => Row(
                      children: [
                        Checkbox(
                          value: item.purchased,
                          onChanged: app.canEdit
                              ? (v) => _save(
                                  context,
                                  app,
                                  list,
                                  list.items
                                      .map(
                                        (i) => i.id == item.id
                                            ? i.copy(purchased: v!)
                                            : i,
                                      )
                                      .toList(),
                                )
                              : null,
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: app.canEdit
                                ? () async {
                                    final edited = await ingredientAmountDialog(
                                      context,
                                      app,
                                      existing: RecipeItem(
                                        item.ingredientId,
                                        item.amount,
                                        item.unit,
                                      ),
                                    );
                                    if (edited != null && context.mounted) {
                                      await _save(
                                        context,
                                        app,
                                        list,
                                        list.items
                                            .map(
                                              (i) => i.id == item.id
                                                  ? ShoppingItem(
                                                      id: i.id,
                                                      ingredientId:
                                                          edited.ingredientId,
                                                      unit: edited.unit,
                                                      amount: edited.amount,
                                                      purchased: i.purchased,
                                                    )
                                                  : i,
                                            )
                                            .toList(),
                                      );
                                    }
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.ingredientName(item.ingredientId),
                                    style: TextStyle(
                                      decoration: item.purchased
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  Text(
                                    '${quantity(item.amount)} ${item.amount == null ? '' : item.unit}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Bỏ mục',
                          onPressed: app.canEdit
                              ? () async {
                                  if (await confirm(
                                        context,
                                        'Bỏ nguyên liệu?',
                                        app.ingredientName(item.ingredientId),
                                      ) &&
                                      context.mounted) {
                                    await _save(
                                      context,
                                      app,
                                      list,
                                      list.items
                                          .where((i) => i.id != item.id)
                                          .toList(),
                                    );
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save(
    BuildContext context,
    AppController app,
    ShoppingList list,
    List<ShoppingItem> items,
  ) async {
    await perform(
      context,
      () => app.save(
        app.book.copy(
          lists: app.book.lists
              .map(
                (l) => l.id == list.id
                    ? ShoppingList(id: l.id, name: l.name, items: items)
                    : l,
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, AppController app) async {
    var range = DateTimeRange(
      start: DateUtils.dateOnly(DateTime.now()),
      end: DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 6)),
    );
    var deduct = true, manual = false;
    var creating = false;
    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          final meals = app.book.meals
              .where(
                (m) =>
                    m.date.compareTo(dayKey(range.start)) >= 0 &&
                    m.date.compareTo(dayKey(range.end)) <= 0,
              )
              .toList();
          final preview = manual
              ? <ShoppingItem>[]
              : shoppingFor(
                  meals,
                  app.book.pantry,
                  DateTime.now(),
                  deductPantry: deduct,
                );
          return AlertDialog(
            title: const Text('Tạo danh sách mua sắm'),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tạo danh sách trống'),
                      value: manual,
                      onChanged: creating
                          ? null
                          : (v) => setState(() => manual = v),
                    ),
                    if (!manual) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          '${dayKey(range.start)} → ${dayKey(range.end)}',
                        ),
                        onPressed: creating
                            ? null
                            : () async {
                                final result = await showDateRangePicker(
                                  context: context,
                                  initialDateRange: range,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (result != null) {
                                  setState(() => range = result);
                                }
                              },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Trừ nguyên liệu có trong tủ lạnh'),
                        subtitle: const Text(
                          'Chỉ lô còn hạn và đơn vị tương thích. Không thay đổi lượng tồn.',
                        ),
                        value: deduct,
                        onChanged: creating
                            ? null
                            : (v) => setState(() => deduct = v),
                      ),
                      Text('${meals.length} món trong khoảng ngày đã chọn'),
                      const Divider(),
                      if (meals.isEmpty)
                        const Text(
                          'Chưa có thực đơn. Thêm món trước hoặc chọn danh sách trống.',
                        ),
                      if (meals.isNotEmpty && preview.isEmpty)
                        const Text(
                          'Không có nguyên liệu cần mua thêm theo đối chiếu hiện tại.',
                        ),
                      ...preview.map(
                        (i) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(app.ingredientName(i.ingredientId)),
                          trailing: Text(
                            '${quantity(i.amount)} ${i.amount == null ? '' : i.unit}',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: creating ? null : () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed:
                    creating || !app.canEdit || (!manual && meals.isEmpty)
                    ? null
                    : () async {
                        setState(() => creating = true);
                        final list = ShoppingList(
                          id: uuid.v4(),
                          name: manual
                              ? 'Danh sách mới'
                              : 'Mua sắm ${dayKey(range.start)} – ${dayKey(range.end)}',
                          items: preview
                              .map(
                                (i) => ShoppingItem(
                                  id: uuid.v4(),
                                  ingredientId: i.ingredientId,
                                  unit: i.unit,
                                  amount: i.amount,
                                ),
                              )
                              .toList(),
                        );
                        final ok = await perform(
                          context,
                          () => app.save(
                            app.book.copy(lists: [...app.book.lists, list]),
                          ),
                        );
                        if (context.mounted) {
                          if (ok) {
                            Navigator.pop(context);
                          } else {
                            setState(() => creating = false);
                          }
                        }
                      },
                child: Text(creating ? 'Đang tạo…' : 'Xác nhận tạo'),
              ),
            ],
          );
        },
      ),
    );
  }
}
