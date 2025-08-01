// lib/main.dart
// ------------------------------------------------------------
// 2025-07-26 – FavoriteStore provider + larger typography
//               + force dark text colors (onSurface) app-wide
// ------------------------------------------------------------
import 'dart:async';
import 'dart:developer';

import 'package:cookbook/screens/change_password_screen.dart'
    show ChangePasswordScreen;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

// --- Services ---
import 'services/api_service.dart';
import 'services/auth_service.dart';

// --- Favorite store ---
import 'stores/favorite_store.dart';

// [NEW] Settings store (สวิตช์ตัดคำภาษาไทยในหน้า Settings)
import 'stores/settings_store.dart';

// --- Screens ---
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/verify_otp_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/new_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/my_recipes_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/all_ingredients_screen.dart';
import 'screens/allergy_screen.dart';
import 'screens/step_detail_screen.dart';
import 'screens/references_screen.dart';
import 'screens/ingredient_filter_screen.dart';

// --- Models & Widgets ---
import 'models/recipe.dart';
import 'models/recipe_step.dart';
import 'widgets/auth_guard.dart';
import 'widgets/error_page.dart';

/* ───────────── GLOBALS ───────────── */
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/* ───────────── MAIN ───────────── */
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('th_TH', null);
  await ApiService.init();
  await AuthService.init();

  // preload favorite ids (ถ้า login อยู่)
  Set<int> favoriteIds = {};
  try {
    if (await AuthService.isLoggedIn()) {
      favoriteIds = (await ApiService.fetchFavoriteIds()).toSet();
    }
  } catch (_) {}

  runZonedGuarded(() {
    FlutterError.onError = (details) {
      log('Flutter framework error:',
          error: details.exception, stackTrace: details.stack);
    };
    runApp(MyApp(initialFavoriteIds: favoriteIds));
  }, (error, stack) {
    log('Uncaught zoned error:', error: error, stackTrace: stack);

    if (error is UnauthorizedException) {
      AuthService.logout().then((_) =>
          navKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false));
      return;
    }

    final context = navKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดไม่คาดคิด: $error')),
      );
    }
  });
}

/* ───────────── APP ───────────── */
class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.initialFavoriteIds});
  final Set<int> initialFavoriteIds;

  @override
  Widget build(BuildContext context) {
    /* — palette — */
    const primaryColor = Color(0xFFFF9B05);
    const primaryContainerColor = Color(0xFFFCC09C);
    const onSurfaceColor = Color(0xFF0A2533);
    const onSurfaceVariantColor = Color(0xFF666666);

    /* — base theme — */
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        brightness: Brightness.light,
        surface: Colors.white,
        onSurface: onSurfaceColor,
        onSurfaceVariant: onSurfaceVariantColor,
      ),
      scaffoldBackgroundColor: const Color(0xFFFEF9F5),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );

    /* — enlarged typography (force dark text color) — */
    final textTheme = GoogleFonts.itimTextTheme(baseTheme.textTheme).copyWith(
      titleLarge: GoogleFonts.itim(
          fontSize: 24, fontWeight: FontWeight.bold, color: onSurfaceColor),
      titleMedium: GoogleFonts.itim(
          fontSize: 20, fontWeight: FontWeight.w700, color: onSurfaceColor),
      bodyLarge: GoogleFonts.itim(
          fontSize: 18, fontWeight: FontWeight.w400, color: onSurfaceColor),
      bodyMedium: GoogleFonts.itim(fontSize: 16, color: onSurfaceColor),
      bodySmall: GoogleFonts.itim(fontSize: 14, color: onSurfaceColor),
      labelLarge: GoogleFonts.itim(
          fontSize: 14, fontWeight: FontWeight.w600, color: onSurfaceColor),
      labelMedium: GoogleFonts.itim(fontSize: 12, color: onSurfaceColor),
      labelSmall: GoogleFonts.itim(fontSize: 11, color: onSurfaceColor),
    );

    /* — component overrides — */
    final appTheme = baseTheme.copyWith(
      textTheme: textTheme,
      appBarTheme: baseTheme.appBarTheme.copyWith(
        elevation: 1,
        centerTitle: true,
        backgroundColor: baseTheme.colorScheme.surface,
        foregroundColor: onSurfaceColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black26,
        titleTextStyle: textTheme.titleLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: primaryColor,
          minimumSize: const Size(0, 56),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle:
              GoogleFonts.itim(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurfaceColor,
          minimumSize: const Size(0, 56),
          shape: const StadiumBorder(),
          side: BorderSide(color: onSurfaceColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle:
              GoogleFonts.itim(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color.fromARGB(181, 116, 108, 95),
          textStyle: GoogleFonts.itim(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        hintStyle: TextStyle(color: onSurfaceVariantColor.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        shadowColor: Colors.black.withOpacity(0.08),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: primaryColor.withOpacity(0.5)),
        backgroundColor: primaryContainerColor.withOpacity(0.2),
        labelStyle:
            GoogleFonts.itim(color: primaryColor, fontWeight: FontWeight.bold),
      ),
      bottomNavigationBarTheme: baseTheme.bottomNavigationBarTheme.copyWith(
        selectedItemColor: primaryColor,
        unselectedItemColor: onSurfaceVariantColor,
        backgroundColor: Colors.white,
        elevation: 8,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.itim(
            fontWeight: FontWeight.bold, color: onSurfaceColor),
        unselectedLabelStyle: GoogleFonts.itim(color: onSurfaceVariantColor),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    /* — providers & app — */
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => FavoriteStore(initialIds: initialFavoriteIds),
        ),
        // [NEW] SettingsStore provider (โหลดค่าดีฟอลต์: ปิดการตัดคำ)
        ChangeNotifierProvider(
          create: (_) => SettingsStore()..load(),
        ),
      ],
      child: MaterialApp(
        title: 'Cooking Guide',
        debugShowCheckedModeBanner: false,
        navigatorKey: navKey,
        navigatorObservers: [routeObserver],
        theme: appTheme,
        initialRoute: '/splash',
        onGenerateRoute: _onGenerateRoute,
        onUnknownRoute: (_) => MaterialPageRoute(
            builder: (_) => const ErrorPage(message: 'ไม่พบหน้าที่คุณเรียก')),
      ),
    );
  }

  /* ───────────── ROUTING ───────────── */
  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    switch (settings.name) {
      /* public */
      case '/splash':
        return _fade(const SplashScreen(), settings);
      case '/onboarding':
        return _fade(const OnboardingScreen(), settings);
      case '/welcome':
        return _fade(const WelcomeScreen(), settings);
      case '/login':
        return _material(const LoginScreen(), settings);
      case '/register':
        return _material(const RegisterScreen(), settings);
      case '/reset_password':
        return _material(const ResetPasswordScreen(), settings);
      case '/verify_otp':
        if (args is String) {
          return _material(VerifyOtpScreen(email: args), settings);
        }
        return _errorRoute('ข้อมูลอีเมลไม่ถูกต้อง');
      case '/new_password':
        if (args is Map<String, String>) {
          return _material(
            NewPasswordScreen(email: args['email']!, otp: args['otp']!),
            settings,
          );
        }
        return _errorRoute('ข้อมูล OTP ไม่ถูกต้อง');

      /* main */
      case '/home':
        return _fade(const HomeScreen(), settings);
      case '/search':
        final p = (args is Map) ? args : null;
        return _material(
          SearchScreen(
            initialSortIndex: p?['initialSortIndex'],
            ingredients: p?['ingredients'],
          ),
          settings,
        );
      case '/recipe_detail':
        if (args is int) {
          return _material(RecipeDetailScreen(recipeId: args), settings);
        }
        if (args is Recipe) {
          return _material(RecipeDetailScreen(recipeId: args.id), settings);
        }
        return _errorRoute('ข้อมูลสูตรอาหารไม่ถูกต้อง');
      case '/step_detail':
        if (args is Map) {
          return _material(
            StepDetailScreen(
              steps: args['steps'] as List<RecipeStep>,
              imageUrls: args['imageUrls'] as List<String>,
              initialIndex: args['initialIndex'] as int,
            ),
            settings,
          );
        }
        return _errorRoute('ข้อมูลขั้นตอนไม่ถูกต้อง');

      /* protected */
      case '/my_recipes':
        return _material(
          AuthGuard(
            child: MyRecipesScreen(initialTab: (args is int) ? args : 0),
          ),
          settings,
        );
      case '/profile':
        return _material(const AuthGuard(child: ProfileScreen()), settings);
      case '/settings':
        return _material(const SettingsScreen(), settings);
      case '/edit_profile':
        return _material(const AuthGuard(child: EditProfileScreen()), settings);
      case '/change_password':
        return _material(
            const AuthGuard(child: ChangePasswordScreen()), settings);
      case '/allergy':
        return _material(const AuthGuard(child: AllergyScreen()), settings);
      case '/references':
        return _material(const ReferencesScreen(), settings);
      case '/all_ingredients':
        return _material(const AllIngredientsScreen(), settings);
      case '/ingredient_filter':
        final p = (args is Map) ? args : null;
        return _material(
          IngredientFilterScreen(
            initialInclude: p?['initialInclude'],
            initialExclude: p?['initialExclude'],
          ),
          settings,
        );
      default:
        return null;
    }
  }

  /* ───────────── HELPERS ───────────── */
  Route<dynamic> _errorRoute(String msg) =>
      MaterialPageRoute(builder: (_) => ErrorPage(message: msg));

  MaterialPageRoute _material(Widget child, RouteSettings s) =>
      MaterialPageRoute(builder: (_) => child, settings: s);

  PageRouteBuilder _fade(Widget child, RouteSettings s) => PageRouteBuilder(
        settings: s,
        pageBuilder: (_, __, ___) => child,
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      );
}
