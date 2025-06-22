// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/my_recipes_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/all_ingredients_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/allergy_screen.dart';

import 'services/auth_service.dart';
import 'models/recipe.dart';

/* ───────────── globals ───────────── */
final navKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/* ───────────── main ───────────── */
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th', null);

  runZonedGuarded(
    () => runApp(const CookingGuideApp()),
    (error, stack) {
      debugPrint('‼️ Uncaught Zone Error → $error\n$stack');
      final ctx = navKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดไม่คาดคิด: $error')),
        );
      }
    },
  );
}

/* ───────────── app ───────────── */
class CookingGuideApp extends StatelessWidget {
  const CookingGuideApp({super.key});

  static const _primary = Color(0xFFFF9B05);

  ThemeData _theme() => ThemeData(
        useMaterial3: false,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: _primary),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary, width: 1.5),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cooking Guide',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      navigatorObservers: [routeObserver],
      theme: _theme(),
      home: const SplashScreen(),
      onGenerateRoute: _onGenerateRoute,
      onUnknownRoute: (_) => _errorRoute('ไม่พบหน้าที่คุณเรียก'),
    );
  }

  /* ───────────── route factory ───────────── */
  Route<dynamic>? _onGenerateRoute(RouteSettings s) {
    switch (s.name) {
      case '/login':
        return _fade((c) => const LoginScreen(), s);

      case '/home':
        return _fade((c) => const HomeScreen(), s);

      case '/search':
        return _material((c) => const SearchScreen(), s);

      case '/recipe_detail':
        if (s.arguments is Recipe) {
          final r = s.arguments as Recipe;
          return _material((c) => RecipeDetailScreen(recipeId: r.id), s);
        }
        return _errorRoute('ข้อมูล recipe ไม่ถูกต้อง');

      case '/my_recipes':
        final arg = s.arguments;
        final tab = (arg is int && (arg == 0 || arg == 1)) ? arg : 0;
        return _material(
          (c) => AuthGuard(child: MyRecipesScreen(initialTab: tab)),
          s,
        );

      case '/profile':
        return _material(
          (c) => AuthGuard(child: const ProfileScreen()),
          s,
        );

      case '/settings':
        return _material(
          (c) => AuthGuard(child: const SettingsScreen()),
          s,
        );

      case '/edit_profile':
        return _material(
          (c) => AuthGuard(child: const EditProfileScreen()),
          s,
        );

      case '/all_ingredients':
        return _material((c) => const AllIngredientsScreen(), s);

      case '/change_password':
        return _material(
          (c) => AuthGuard(child: const ChangePasswordScreen()),
          s,
        );

      case '/allergy':
        return _material(
          (c) => AuthGuard(child: const AllergyScreen()),
          s,
        );
      default:
        return null;
    }
  }

  /* ───────────── helpers ───────────── */
  Route<dynamic> _errorRoute(String msg) =>
      _material((c) => _ErrorPage(message: msg), const RouteSettings());

  MaterialPageRoute _material(WidgetBuilder b, RouteSettings s) =>
      MaterialPageRoute(builder: b, settings: s);

  PageRouteBuilder _fade(WidgetBuilder b, RouteSettings s) => PageRouteBuilder(
        settings: s,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (c, _, __) => b(c),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      );
}

/* ───────────── auth guard ───────────── */
class AuthGuard extends StatelessWidget {
  const AuthGuard({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data == true ? child : const LoginScreen();
      },
    );
  }
}

/* ───────────── fallback page ───────────── */
class _ErrorPage extends StatelessWidget {
  const _ErrorPage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: AlertDialog(
            title: const Text('เกิดข้อผิดพลาด'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/home'),
                child: const Text('กลับหน้าหลัก'),
              ),
            ],
          ),
        ),
      );
}
