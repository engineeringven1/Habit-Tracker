import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_colors.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/dark_mode_provider.dart';
import 'core/theme/palette_provider.dart';
import 'data/supabase/supabase_config.dart';
import 'features/auth/login_screen.dart';
import 'features/arena/arena_screen.dart';
import 'features/habits/habits_screen.dart';
import 'features/mentor/mentor_screen.dart';
import 'features/stats/stats_screen.dart';
import 'features/tracker/tracker_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  await NotificationService.init();
  await preloadTheme();
  runApp(const ProviderScope(child: HabitTrackerApp()));
}

// ─── Router ───────────────────────────────────────────────────────────────────

final _router = GoRouter(
  initialLocation: '/tracker',
  redirect: (context, state) {
    final isLoggedIn =
        Supabase.instance.client.auth.currentUser != null;
    final isLoginRoute = state.matchedLocation == '/login';
    if (!isLoggedIn && !isLoginRoute) return '/login';
    if (isLoggedIn && isLoginRoute) return '/tracker';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, _) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (_, state, child) => _MainShell(
        location: state.matchedLocation,
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/tracker',
          builder: (_, _) => const TrackerScreen(),
        ),
        GoRoute(
          path: '/stats',
          builder: (_, _) => const StatsScreen(),
        ),
        GoRoute(
          path: '/mentor',
          builder: (_, _) => const MentorScreen(),
        ),
        GoRoute(
          path: '/arena',
          builder: (_, _) => const ArenaScreen(),
        ),
        GoRoute(
          path: '/habits',
          builder: (_, _) => const HabitsScreen(),
        ),
      ],
    ),
  ],
);

// ─── App ──────────────────────────────────────────────────────────────────────

class HabitTrackerApp extends ConsumerWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final isDark  = ref.watch(darkModeProvider);
    // ValueKey forces full rebuild when palette or dark/light mode changes,
    // ensuring every widget reading AppColors directly picks up new colours.
    return MaterialApp.router(
      key: ValueKey('${palette.id}_$isDark'),
      title: 'Habit OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}

// ─── Main Shell with NavigationBar ───────────────────────────────────────────

class _MainShell extends StatelessWidget {
  final String location;
  final Widget child;

  const _MainShell({required this.location, required this.child});

  int get _selectedIndex {
    if (location.startsWith('/stats')) return 1;
    if (location.startsWith('/mentor')) return 2;
    if (location.startsWith('/arena')) return 3;
    if (location.startsWith('/habits')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/tracker');
            case 1:
              context.go('/stats');
            case 2:
              context.go('/mentor');
            case 3:
              context.go('/arena');
            case 4:
              context.go('/habits');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline_rounded),
            selectedIcon: Icon(Icons.check_circle_rounded),
            label: 'Hoy',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology_rounded),
            label: 'Mentor',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Arena',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Config',
          ),
        ],
      ),
    );
  }
}
