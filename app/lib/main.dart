import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_controller.dart';
import 'data/kitchen_repository.dart';
import 'data/recipe_api.dart';
import 'data/local_store.dart';
import 'services/reminders.dart';
import 'ui/auth.dart';
import 'ui/home.dart';
import 'ui/recipes.dart';
import 'ui/planning.dart';
import 'ui/pantry.dart';
import 'ui/shopping.dart';
import 'ui/suggestions.dart';
import 'ui/shared.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  RecipeApi api;
  try {
    api = RecipeApi(baseUrl: baseUrl);
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Chưa có địa chỉ API hợp lệ. Chạy ứng dụng với tệp cấu hình API_BASE_URL theo README.',
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  final router = createRouter();
  final reminders = Reminders(onOpen: () => router.go('/pantry'));
  String? warning;
  var launchPantry = false;
  try {
    await reminders.initialize();
    launchPantry =
        (await reminders.plugin.getNotificationAppLaunchDetails())
            ?.didNotificationLaunchApp ??
        false;
  } catch (_) {
    warning = 'Chưa khởi tạo được nhắc hạn; các chức năng khác vẫn dùng được.';
  }
  final app = AppController(
    repository: KitchenRepository(local: LocalStore(), api: api),
    reminders: reminders,
  );
  runApp(
    ProviderScope(
      overrides: [appProvider.overrideWith((ref) => app)],
      child: NauGiApp(router: router),
    ),
  );
  unawaited(
    app.initialize().then((_) {
      if (warning != null) app.setNotice(warning);
      if (launchPantry) router.go('/pantry');
    }),
  );
}

GoRouter createRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const ShellScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: '/recipe/new', builder: (_, _) => const RecipeEditor()),
    GoRoute(
      path: '/recipe/:id',
      builder: (_, state) => RecipeScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/recipe/:id/edit',
      builder: (_, state) => RecipeEditor(id: state.pathParameters['id']!),
    ),
    GoRoute(path: '/pantry', builder: (_, _) => const PantryScreen()),
    GoRoute(path: '/ingredients', builder: (_, _) => const IngredientsScreen()),
    GoRoute(path: '/suggestions', builder: (_, _) => const SuggestionsScreen()),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => context.go('/'),
        child: const Text('Về trang chủ'),
      ),
    ),
  ),
);

class NauGiApp extends StatelessWidget {
  final GoRouter router;
  const NauGiApp({super.key, required this.router});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'NauGi • Nấu gì?',
    debugShowCheckedModeBanner: false,
    routerConfig: router,
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFAF8F2),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF386B4E),
        primary: const Color(0xFF386B4E),
        secondary: const Color(0xFFBF7547),
        surface: const Color(0xFFFAF8F2),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAF8F2),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
  );
}

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});
  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    if (!app.ready) {
      return Scaffold(
        body: Center(
          child: app.localFailure == null
              ? const CircularProgressIndicator()
              : EmptyState(
                  title: 'Chưa mở được sổ tay',
                  description: app.localFailure!.message,
                  action: FilledButton(
                    onPressed: app.initialize,
                    child: const Text('Thử lại'),
                  ),
                ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NauGi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Tủ lạnh',
            onPressed: () => context.push('/pantry'),
            icon: const Icon(Icons.kitchen_outlined),
          ),
          IconButton(
            tooltip: 'Cài đặt',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (app.notice != null)
              MaterialBanner(
                content: Text(app.notice!),
                actions: [
                  TextButton(
                    onPressed: () => app.setNotice(null),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            Expanded(
              child: IndexedStack(
                index: index,
                children: const [
                  HomeScreen(),
                  RecipesScreen(),
                  PlanningScreen(),
                  ShoppingScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            label: 'Hôm nay',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Công thức',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Thực đơn',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_basket_outlined),
            label: 'Mua sắm',
          ),
        ],
      ),
    );
  }
}
