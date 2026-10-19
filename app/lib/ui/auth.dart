import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_controller.dart';
import '../domain/models.dart';
import 'shared.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? draftMinutes;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final drafts =
        app.book.draftRecipes.length + app.book.draftIngredients.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Thực đơn, tủ lạnh, mua sắm, yêu thích và ảnh lưu trên thiết bị. Thư viện công thức dùng chung qua API.',
          ),
          CatalogStatus(app: app),
          OutlinedButton.icon(
            onPressed: app.refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Làm mới thư viện'),
          ),
          if (app.notice != null) Text(app.notice!),
          if (drafts > 0)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Có $drafts bản nháp từ phiên bản cũ. Bản sao dữ liệu gốc được giữ trên thiết bị.',
                    ),
                    FilledButton(
                      onPressed: app.canWriteRemote
                          ? () async {
                              if (!await confirm(
                                context,
                                'Nhập bản nháp lên thư viện chung?',
                                'Công thức và nguyên liệu sẽ được gửi lên API. Thư viện này dùng chung, không phải dữ liệu riêng tư. Bản trùng khác nội dung sẽ được giữ lại.',
                              )) {
                                return;
                              }
                              if (context.mounted) {
                                await perform(context, app.importDrafts);
                              }
                            }
                          : null,
                      child: const Text('Nhập bản nháp'),
                    ),
                  ],
                ),
              ),
            ),
          _preferences(app),
        ],
      ),
    );
  }

  Widget _preferences(AppController app) {
    final p = app.book.preferences;
    Future<void> update({
      bool? vegetarian,
      bool? reminders,
      int? servings,
      int? minutes,
      List<String>? avoided,
    }) => perform(
      context,
      () => app.save(
        app.book.copy(
          preferences: Preferences(
            vegetarian: vegetarian ?? p.vegetarian,
            reminders: reminders ?? p.reminders,
            servings: servings ?? p.servings,
            maxMinutes: minutes ?? p.maxMinutes,
            avoided: avoided ?? p.avoided,
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Sở thích của bạn'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Chỉ gợi ý món chay'),
          value: p.vegetarian,
          onChanged: app.canEdit ? (v) => update(vegetarian: v) : null,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Khẩu phần mặc định'),
          trailing: SizedBox(
            width: 100,
            child: DropdownButton<int>(
              value: p.servings,
              items: List.generate(
                12,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text('${i + 1} người'),
                ),
              ),
              onChanged: app.canEdit ? (v) => update(servings: v) : null,
            ),
          ),
        ),
        Text('Thời gian nấu tối đa: ${draftMinutes ?? p.maxMinutes} phút'),
        Slider(
          value: (draftMinutes ?? p.maxMinutes).toDouble(),
          min: 10,
          max: 120,
          divisions: 22,
          label: '${draftMinutes ?? p.maxMinutes} phút',
          onChanged: app.canEdit
              ? (v) => setState(() => draftMinutes = v.round())
              : null,
          onChangeEnd: app.canEdit
              ? (v) async {
                  await update(minutes: v.round());
                  if (mounted) setState(() => draftMinutes = null);
                }
              : null,
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.block),
          label: Text('Nguyên liệu muốn tránh (${p.avoided.length})'),
          onPressed: !app.canEdit
              ? null
              : () async {
                  final selected = p.avoided.toSet();
                  final result = await showDialog<List<String>>(
                    context: context,
                    builder: (_) => StatefulBuilder(
                      builder: (context, setState) => AlertDialog(
                        title: const Text('Nguyên liệu muốn tránh'),
                        content: SizedBox(
                          width: 360,
                          height: 350,
                          child: ListView(
                            children: app.catalog.values
                                .map(
                                  (i) => CheckboxListTile(
                                    title: Text(i.name),
                                    value: selected.contains(i.id),
                                    onChanged: (v) => setState(() {
                                      v!
                                          ? selected.add(i.id)
                                          : selected.remove(i.id);
                                    }),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Hủy'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, selected.toList()),
                            child: const Text('Lưu'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (result != null) await update(avoided: result);
                },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Nhắc hạn thực phẩm'),
          subtitle: const Text('Khoảng 8 giờ • trước 2 ngày và ngày hết hạn'),
          value: p.reminders,
          onChanged: !app.canEdit
              ? null
              : (v) async {
                  if (v) {
                    final granted = await app.requestRemindersPermission();
                    if (!granted) {
                      if (mounted) {
                        message(context, 'Chưa được cấp quyền thông báo.');
                      }
                      return;
                    }
                  }
                  await update(reminders: v);
                },
        ),
        TextButton(
          onPressed: () => context.push('/ingredients'),
          child: const Text('Nguyên liệu & dữ liệu dinh dưỡng'),
        ),
        if (const bool.fromEnvironment('dart.vm.product') == false)
          TextButton(
            onPressed: () => perform(context, () async {
              await app.testReminder();
            }, success: 'Đã đặt lịch nhắc thử sau khoảng 1 phút.'),
            child: const Text('Thử thông báo (bản phát triển)'),
          ),
      ],
    );
  }
}
