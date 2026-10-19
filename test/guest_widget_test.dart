import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naugi/app_controller.dart';
import 'package:naugi/main.dart';
import 'support.dart';

void main() {
  testWidgets('welcome enters guest and opens recipe nutrition', (
    tester,
  ) async {
    if (const bool.fromEnvironment('CAPTURE_SCREENSHOTS')) {
      await tester.runAsync(() async {
        final font = FontLoader('Roboto');
        font.addFont(
          File(
            '.tools/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        );
        await font.load();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(
          File(
            '.tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        );
        await icons.load();
      });
    }
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppController(local: MemoryStore());
    await app.initialize();
    final router = createRouter();
    const boundaryKey = ValueKey('screenshot');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: ProviderScope(
          overrides: [appProvider.overrideWith((ref) => app)],
          child: NauGiApp(router: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tiếp tục với tư cách khách'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục với tư cách khách'));
    await tester.pumpAndSettle();
    expect(find.text('NauGi'), findsOneWidget);
    expect(find.text('Khách'), findsOneWidget);
    if (const bool.fromEnvironment('CAPTURE_SCREENSHOTS')) {
      await capture(tester, boundaryKey, 'home');
    }
    await tester.tap(find.text('Công thức'));
    await tester.pumpAndSettle();
    expect(find.text('Sổ tay công thức'), findsOneWidget);
    await tester.tap(find.text('Gà kho gừng').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Mỗi khẩu phần'), 200);
    expect(find.text('Mỗi khẩu phần'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_SCREENSHOTS')) {
      await capture(tester, boundaryKey, 'recipe');
    }
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
  testWidgets('guest creates a recipe using the actual editor form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppController(local: MemoryStore());
    await app.enterGuest();
    final router = createRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((ref) => app)],
        child: NauGiApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/recipe/new');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cơm thử nghiệm');
    await tester.scrollUntilVisible(
      find.text('Thêm'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Số lượng'),
      '100',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
      find.text('Các bước thực hiện'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Các bước thực hiện'),
      'Vo gạo.\n\nNấu chín.',
    );
    await tester.scrollUntilVisible(
      find.text('Lưu công thức'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Lưu công thức'));
    await tester.pumpAndSettle();
    expect(app.book.recipes.single.name, 'Cơm thử nghiệm');
    expect(app.book.recipes.single.items.single.amount, 100);
    expect(app.book.recipes.single.steps.length, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}

Future<void> capture(WidgetTester tester, Key key, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/screenshots');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
