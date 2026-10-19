import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_controller.dart';
import '../domain/models.dart';
import 'shared.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool register = false, working = false, recoverySent = false;
  int? draftMinutes;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> auth(Future<void> Function() action) async {
    setState(() => working = true);
    try {
      await action();
    } on AuthException catch (error) {
      if (mounted) message(context, 'Không đăng nhập được: ${error.message}');
    } catch (_) {
      if (mounted) {
        message(
          context,
          'Không kết nối được dịch vụ tài khoản. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  static const redirect = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'vn.naugi.app://login-callback/',
  );
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    if (app.signedIn && !app.passwordRecovery) return _profile(app);
    return Scaffold(
      appBar: AppBar(title: const Text('NauGi • Nấu gì?')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.ramen_dining,
                size: 72,
                color: Color(0xFF386B4E),
              ),
              const SizedBox(height: 24),
              Text(
                app.passwordRecovery
                    ? 'Đặt mật khẩu mới'
                    : 'Một căn bếp gọn gàng.\nMỗi ngày một món ngon.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sổ tay công thức, thực đơn và nguyên liệu của riêng bạn.',
              ),
              const SizedBox(height: 24),
              if (app.client == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Chế độ khách sẵn sàng. Đăng nhập hiện chưa khả dụng.',
                  ),
                ),
              Form(
                key: form,
                child: Column(
                  children: [
                    if (!app.passwordRecovery) ...[
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) =>
                            v != null &&
                                RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(v.trim())
                            ? null
                            : 'Nhập email hợp lệ',
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Mật khẩu'),
                      validator: (v) =>
                          (v?.length ?? 0) < 8 ? 'Dùng ít nhất 8 ký tự' : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: working || app.client == null
                            ? null
                            : () => auth(() async {
                                if (!form.currentState!.validate()) return;
                                if (app.passwordRecovery) {
                                  await app.client!.auth.updateUser(
                                    UserAttributes(password: password.text),
                                  );
                                  app.finishRecovery();
                                  if (context.mounted) context.go('/');
                                } else if (register) {
                                  await app.client!.auth.signUp(
                                    email: email.text.trim(),
                                    password: password.text,
                                    emailRedirectTo: redirect,
                                  );
                                  if (context.mounted) {
                                    message(
                                      context,
                                      'Đã gửi yêu cầu đăng ký. Kiểm tra email xác nhận trước khi đăng nhập.',
                                    );
                                  }
                                } else {
                                  await app.client!.auth.signInWithPassword(
                                    email: email.text.trim(),
                                    password: password.text,
                                  );
                                  if (context.mounted) context.go('/');
                                }
                              }),
                        child: Text(
                          working
                              ? 'Đang xử lý…'
                              : app.passwordRecovery
                              ? 'Lưu mật khẩu'
                              : register
                              ? 'Tạo tài khoản'
                              : 'Đăng nhập',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!app.passwordRecovery) ...[
                TextButton(
                  onPressed: working
                      ? null
                      : () => setState(() => register = !register),
                  child: Text(
                    register
                        ? 'Đã có tài khoản? Đăng nhập'
                        : 'Chưa có tài khoản? Đăng ký',
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Tiếp tục với Google'),
                  onPressed: working || app.client == null
                      ? null
                      : () => auth(() async {
                          await app.client!.auth.signInWithOAuth(
                            OAuthProvider.google,
                            redirectTo: redirect,
                          );
                        }),
                ),
                TextButton(
                  onPressed: working || app.client == null
                      ? null
                      : () => auth(() async {
                          if (!RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(email.text.trim())) {
                            message(
                              context,
                              'Nhập email trước khi yêu cầu đặt lại mật khẩu.',
                            );
                            return;
                          }
                          await app.client!.auth.resetPasswordForEmail(
                            email.text.trim(),
                            redirectTo: redirect,
                          );
                          if (mounted) setState(() => recoverySent = true);
                        }),
                  child: const Text('Quên mật khẩu?'),
                ),
                if (recoverySent)
                  const Text('Kiểm tra email để mở liên kết đặt lại mật khẩu.'),
                const Divider(height: 32),
                FilledButton.tonal(
                  onPressed: working || app.busy
                      ? null
                      : () async {
                          final ok = await perform(context, app.enterGuest);
                          if (ok && context.mounted) context.go('/');
                        },
                  child: Text(
                    app.guest
                        ? 'Trở lại sổ tay khách'
                        : 'Tiếp tục với tư cách khách',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Dữ liệu khách lưu trên thiết bị. Gỡ ứng dụng hoặc xóa dữ liệu có thể làm mất sổ tay.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
                if (app.guest) ...[
                  const SizedBox(height: 24),
                  _preferences(app),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _profile(AppController app) => Scaffold(
    appBar: AppBar(title: const Text('Tài khoản & cài đặt')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CircleAvatar(radius: 32, child: Icon(Icons.person, size: 36)),
        const SizedBox(height: 12),
        Text(
          app.client?.auth.currentUser?.email ?? 'Tài khoản NauGi',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (app.offline)
          const Text('Đang xem bản lưu ngoại tuyến. Đồng bộ lại để chỉnh sửa.'),
        OutlinedButton.icon(
          onPressed: app.busy ? null : app.loadAccount,
          icon: const Icon(Icons.sync),
          label: const Text('Đồng bộ dữ liệu'),
        ),
        FutureBuilder<bool>(
          future: app.hasGuestData,
          builder: (context, snapshot) => snapshot.data == true
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bạn có dữ liệu khách trên thiết bị',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'Chuyển vào tài khoản này; giữ dữ liệu hiện có. Chỉ xóa bản khách sau khi máy chủ xác nhận lưu.',
                        ),
                        TextButton(
                          onPressed: !app.canEdit
                              ? null
                              : () async {
                                  if (await confirm(
                                    context,
                                    'Chuyển dữ liệu khách?',
                                    'Ghép công thức, thực đơn, tủ lạnh và danh sách mua vào tài khoản hiện tại.',
                                  )) {
                                    if (context.mounted) {
                                      await perform(
                                        context,
                                        app.importGuest,
                                        success: 'Đã chuyển dữ liệu khách.',
                                      );
                                    }
                                  }
                                },
                          child: const Text('Chuyển dữ liệu'),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        _preferences(app),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: app.busy
              ? null
              : () async {
                  final ok = await perform(context, app.logout);
                  if (ok && mounted) context.go('/');
                },
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
        ),
      ],
    ),
  );

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
                    final granted =
                        await app.reminders?.requestPermission() ?? false;
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
              await app.reminders?.test();
            }, success: 'Đã đặt lịch nhắc thử sau khoảng 1 phút.'),
            child: const Text('Thử thông báo (bản phát triển)'),
          ),
      ],
    );
  }
}
