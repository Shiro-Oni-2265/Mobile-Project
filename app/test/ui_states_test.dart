import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:naugi/app_controller.dart';
import 'package:naugi/domain/models.dart';
import 'package:naugi/main.dart';

import 'support.dart';

Future<GoRouter> mountApp(
  WidgetTester tester,
  AppController app, {
  String path = '/',
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = createRouter();
  if (path != '/') router.go(path);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appProvider.overrideWith((ref) => app)],
      child: NauGiApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
  return router;
}

void main() {
  testWidgets('first offline visit has retry and never pretends seed loaded', (
    tester,
  ) async {
    final server = TestApiServer()..offline = true;
    final app = AppController(repository: server.repository(MemoryStore()));
    await app.initialize();
    await mountApp(tester, app);
    await tester.tap(find.text('Công thức'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được thư viện'), findsOneWidget);
    expect(find.text('Thư viện chưa có công thức'), findsNothing);
    expect(find.text('Gà kho gừng'), findsNothing);
    expect(find.text('Đăng nhập'), findsNothing);
    server.offline = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Gà kho gừng'), findsOneWidget);
    expect(find.text('Chưa tải được thư viện'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh failure keeps cached rows and labels the cache', (
    tester,
  ) async {
    final server = TestApiServer();
    final app = AppController(repository: server.repository(MemoryStore()));
    await app.initialize();
    server.offline = true;
    await app.refresh();
    await mountApp(tester, app);
    await tester.tap(find.text('Công thức'));
    await tester.pumpAndSettle();
    expect(find.text('Đang dùng bản lưu trên thiết bị'), findsOneWidget);
    expect(find.text('Gà kho gừng'), findsOneWidget);
    expect(find.text('Chưa tải được thư viện'), findsNothing);
  });

  testWidgets('valid empty result differs from error and replaces old rows', (
    tester,
  ) async {
    final server = TestApiServer();
    final app = AppController(repository: server.repository(MemoryStore()));
    await app.initialize();
    server.recipes.clear();
    server.ingredients.clear();
    await app.refresh();
    await mountApp(tester, app);
    await tester.tap(find.text('Công thức'));
    await tester.pumpAndSettle();
    expect(find.text('Thư viện chưa có công thức'), findsOneWidget);
    expect(find.text('Gà kho gừng'), findsNothing);
    expect(find.text('Thử lại'), findsNothing);
  });

  testWidgets('tab changes retain recipe search and selected planning week', (
    tester,
  ) async {
    final app = AppController(
      repository: TestApiServer().repository(MemoryStore()),
    );
    await app.initialize();
    await mountApp(tester, app);
    await tester.tap(find.text('Công thức'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'gừng');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thực đơn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tuần sau'));
    await tester.pumpAndSettle();
    final weekFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          RegExp(
            r'\d{2}/\d{2} – \d{2}/\d{2}/\d{4}',
          ).hasMatch(widget.data ?? ''),
    );
    final nextWeek = tester.widget<Text>(weekFinder).data;
    await tester.tap(find.text('Công thức'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text ??
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
      'gừng',
    );
    expect(find.text('Gà kho gừng'), findsOneWidget);
    await tester.tap(find.text('Thực đơn'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(weekFinder).data, nextWeek);
  });

  testWidgets('failed ingredient write keeps dialog and entered name', (
    tester,
  ) async {
    final server = TestApiServer();
    final app = AppController(repository: server.repository(MemoryStore()));
    await app.initialize();
    await mountApp(tester, app, path: '/ingredients');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên nguyên liệu'),
      'Nguyên liệu chưa gửi',
    );
    server.offline = true;
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Tên nguyên liệu'),
          )
          .controller!
          .text,
      'Nguyên liệu chưa gửi',
    );
    expect(
      app.catalog.values.any((i) => i.name == 'Nguyên liệu chưa gửi'),
      isFalse,
    );
    server.offline = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      app.catalog.values.where((i) => i.name == 'Nguyên liệu chưa gửi'),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a lot works when the ingredient catalog is empty', (
    tester,
  ) async {
    final store = MemoryStore();
    store.data['guest'] = const Notebook(
      pantry: [
        PantryLot(
          id: 'lot',
          ingredientId: 'deleted-ingredient',
          amount: 100,
          unit: 'g',
          expiry: '2099-01-01',
        ),
      ],
    );
    final server = TestApiServer()..ingredients.clear();
    final app = AppController(repository: server.repository(store));
    await app.initialize();
    await mountApp(tester, app, path: '/pantry');
    await tester.tap(find.text('deleted-ingredient'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('missing detail while offline offers retry, not deletion claim', (
    tester,
  ) async {
    final server = TestApiServer()..offline = true;
    final app = AppController(repository: server.repository(MemoryStore()));
    await app.initialize();
    await mountApp(tester, app, path: '/recipe/unknown');
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Công thức có thể đã bị xóa.'), findsNothing);
  });

  testWidgets('sample edit URL does not expose editable recipe form', (
    tester,
  ) async {
    final app = AppController(
      repository: TestApiServer().repository(MemoryStore()),
    );
    await app.initialize();
    final sample = app.allRecipes.firstWhere((r) => r.sample);
    await mountApp(tester, app, path: '/recipe/${sample.id}/edit');
    expect(find.widgetWithText(TextFormField, 'Tên món'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ingredient catalog renders a genuine empty result', (
    tester,
  ) async {
    final server = TestApiServer();
    server.ingredients.clear();
    final app = AppController(repository: server.repository(MemoryStore()));
    await app.initialize();
    await mountApp(tester, app, path: '/ingredients');
    expect(find.text('Danh mục chưa có nguyên liệu'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
  });

  testWidgets(
    'planning chooser retries failed load and filters recovered rows',
    (tester) async {
      final server = TestApiServer()..offline = true;
      final app = AppController(repository: server.repository(MemoryStore()));
      await app.initialize();
      await mountApp(tester, app);
      await tester.tap(find.text('Thực đơn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm món').first);
      await tester.pumpAndSettle();
      expect(find.text('Chưa tải được thư viện'), findsOneWidget);
      server.offline = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Gà kho gừng'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Tìm công thức'),
        'từ khóa không tồn tại',
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa tìm thấy món'), findsOneWidget);
      expect(find.text('Gà kho gừng'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
