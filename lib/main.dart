import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_controller.dart';
import 'data/local_store.dart';
import 'services/reminders.dart';
import 'ui/auth.dart';
import 'ui/home.dart';
import 'ui/recipes.dart';
import 'ui/planning.dart';
import 'ui/pantry.dart';
import 'ui/shopping.dart';
import 'ui/suggestions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  SupabaseClient? client;
  String? startupWarning;
  if (url.isNotEmpty && key.isNotEmpty) {
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      client = Supabase.instance.client;
    } catch (_) {
      startupWarning =
          'Chưa khởi tạo được dịch vụ tài khoản. Bạn vẫn có thể dùng chế độ khách.';
    }
  }
  final router = createRouter();
  final reminders = Reminders(onOpen: () => router.go('/pantry'));
  var openPantryOnLaunch = false;
  try {
    await reminders.initialize();
    final launch = await reminders.plugin.getNotificationAppLaunchDetails();
    openPantryOnLaunch = launch?.didNotificationLaunchApp ?? false;
  } catch (_) {
    startupWarning ??=
        'Chưa khởi tạo được nhắc hạn; kiểm tra quyền trong Cài đặt.';
  }
  final app = AppController(
    local: LocalStore(),
    client: client,
    reminders: reminders,
  );
  runApp(
    ProviderScope(
      overrides: [appProvider.overrideWith((ref) => app)],
      child: NauGiApp(router: router),
    ),
  );
  try {
    await app.initialize();
    if (openPantryOnLaunch) {
      if (app.userId == null) await app.enterGuest();
      router.go('/pantry');
    }
  } catch (_) {
    app.initializationFailed();
  }
  if (startupWarning != null) app.setNotice(startupWarning);
}

GoRouter createRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const ShellScreen()),
    GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if ((!app.guest && !app.signedIn) || app.passwordRecovery) {
      return const AccountScreen();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NauGi',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1),
        ),
        actions: [
          if (app.guest) const Chip(label: Text('Khách')),
          IconButton(
            tooltip: 'Tủ lạnh',
            onPressed: () => context.push('/pantry'),
            icon: const Icon(Icons.kitchen_outlined),
          ),
          IconButton(
            tooltip: 'Tài khoản',
            onPressed: () => context.push('/account'),
            icon: const Icon(Icons.person_outline),
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
                  if (!app.guest)
                    TextButton(
                      onPressed: app.busy ? null : app.loadAccount,
                      child: const Text('Đồng bộ'),
                    ),
                  TextButton(
                    onPressed: () {
                      app.setNotice(null);
                    },
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            if (app.busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: switch (index) {
                0 => const HomeScreen(),
                1 => const RecipesScreen(),
                2 => const PlanningScreen(),
                _ => const ShoppingScreen(),
              },
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
            selectedIcon: Icon(Icons.wb_sunny),
            label: 'Hôm nay',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Công thức',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Thực đơn',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_basket_outlined),
            selectedIcon: Icon(Icons.shopping_basket),
            label: 'Mua sắm',
          ),
        ],
      ),
    );
  }
}
