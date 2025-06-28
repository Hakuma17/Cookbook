// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';

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

import 'models/recipe.dart';

/* ───────────── globals ───────────── */
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/* ───────────── main ───────────── */
Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await ApiService.initBaseUrl(); // ตั้งค่า base URL
    await initializeDateFormatting('th', null); // load locale TH

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Flutter framework error: ${details.exception}');
    };

    runApp(const CookingGuideApp());
  }, (error, stack) async {
    debugPrint('Uncaught zone error → $error\n$stack');

    if ('$error'.contains('401') || '$error'.contains('Unauthenticated')) {
      await AuthService.logout(silent: true);
      navKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    final ctx = navKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดไม่คาดคิด: $error')),
      );
    }
  });
}

/* ───────────── app ───────────── */
class CookingGuideApp extends StatelessWidget {
  const CookingGuideApp({super.key});
  static const _primary = Color(0xFFFF9B05);

  ThemeData _theme() => ThemeData(
        useMaterial3: false,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: _primary),

        // 🔹 ไม่ใช้ GoogleFonts อีกต่อไป – Roboto (default) จะถูกใช้อัตโนมัติ
        // ถ้าอยากปรับขนาด/น้ำหนักก็กำหนดใน TextTheme ตามปกติ
        // textTheme: const TextTheme(...),

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
  Widget build(BuildContext context) => MaterialApp(
        title: 'Cooking Guide',
        debugShowCheckedModeBanner: false,
        navigatorKey: navKey,
        navigatorObservers: [routeObserver],
        theme: _theme(),
        home: const SplashScreen(),
        onGenerateRoute: _onGenerateRoute,
        onUnknownRoute: (_) => _errorRoute('ไม่พบหน้าที่คุณเรียก'),
      );

  /* ───────────── route factory ───────────── */
  Route<dynamic>? _onGenerateRoute(RouteSettings s) {
    switch (s.name) {
      case '/login':
        return _fade((_) => const LoginScreen(), s);

      case '/home':
        return _fade((_) => const HomeScreen(), s);

      case '/search':
        return _material((_) => const SearchScreen(), s);

      case '/recipe_detail':
        if (s.arguments case final Recipe r) {
          return _material((_) => RecipeDetailScreen(recipeId: r.id), s);
        }
        return _errorRoute('ข้อมูล recipe ไม่ถูกต้อง');

      case '/my_recipes':
        final tab = (s.arguments is int && (s.arguments as int) <= 1)
            ? s.arguments as int
            : 0;
        return _material(
          (_) => AuthGuard(child: MyRecipesScreen(initialTab: tab)),
          s,
        );

      case '/profile':
        return _material((_) => const AuthGuard(child: ProfileScreen()), s);

      case '/settings':
        return _material((_) => const AuthGuard(child: SettingsScreen()), s);

      case '/edit_profile':
        return _material((_) => const AuthGuard(child: EditProfileScreen()), s);

      case '/all_ingredients':
        return _material((_) => const AllIngredientsScreen(), s);

      case '/change_password':
        return _material(
            (_) => const AuthGuard(child: ChangePasswordScreen()), s);

      case '/allergy':
        return _material((_) => const AuthGuard(child: AllergyScreen()), s);

      default:
        return null;
    }
  }

  /* ───────────── helpers ───────────── */
  Route<dynamic> _errorRoute(String msg) =>
      _material((_) => _ErrorPage(message: msg), const RouteSettings());

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
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: AuthService.isLoggedIn(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.data == true) return child;

          ApiService.clearSession();
          return const LoginScreen();
        },
      );
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
