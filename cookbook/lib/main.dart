// lib/main.dart
// ------------------------------------------------------------
// 2025-07-26 – FavoriteStore provider + larger typography
//               + force dark text colors (onSurface) app-wide
// 2025-08-02 – ↑ label sizes (labelMedium/labelLarge ≥ 16sp),
//               keep chip label at 14sp
// 2025-08-08 – ★ Switch to app_theme (Light/Dark), keep GoogleFonts,
//               remove hard-coded palette; derive from ColorScheme
//               + minor safety around observers
// 2025-08-10 – ★ Split OTP routes:
//               - /verify_email  → VerifyOtpScreen (ยืนยันอีเมลหลังสมัคร)
//               - /verify_otp    → OtpVerificationScreen (ลืมรหัสผ่าน)
// 2025-08-14 – ★★ Theming ปุ่มให้ "เท่ากันทั้งระบบ":
//               + เพิ่ม filledButtonTheme (minHeight 56, StadiumBorder)
//               + จูน outlinedButtonTheme ให้สอดคล้อง (optional side=cs.outline)
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

// --- Services: init พื้นฐาน HTTP/Auth ---
import 'services/api_service.dart';
import 'services/auth_service.dart';

// --- Stores: state แบบเบา ๆ ---
import 'stores/favorite_store.dart';
// [NEW] SettingsStore: โหมดธีม + สวิตช์ตัดคำไทย
import 'stores/settings_store.dart';

// --- Screens: หน้าต่าง ๆ ของแอป ---
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

// ⚠️ มี 2 หน้าชื่อคล้ายกัน แยก route ชัดเจน
import 'screens/verify_otp_screen.dart'
    show VerifyOtpScreen; // ยืนยันอีเมลหลังสมัคร
import 'screens/otp_verification_screen.dart'
    show OtpVerificationScreen; // OTP สำหรับลืมรหัสผ่าน

import 'screens/reset_password_screen.dart';
import 'screens/new_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/my_recipes_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/edit_profile_screen.dart' as edit_profile;
import 'screens/all_ingredients_screen.dart';
import 'screens/allergy_screen.dart';
import 'screens/step_detail_screen.dart';
import 'screens/references_screen.dart';
import 'screens/ingredient_filter_screen.dart';

// --- Models & Widgets เสริม ---
import 'models/recipe.dart';
import 'models/recipe_step.dart';
import 'widgets/auth_guard.dart';
import 'widgets/error_page.dart';

// ★ Theme รวม Light/Dark
import 'theme/app_theme.dart';

/* ───────────── GLOBALS: key/observer ───────────── */
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/* ───────────── MAIN: init ระบบ, preload, error guard ───────────── */
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

  // ครอบด้วย runZonedGuarded: จับ error รวมทั้ง async
  runZonedGuarded(() {
    FlutterError.onError = (details) {
      log('Flutter framework error:',
          error: details.exception, stackTrace: details.stack);
    };
    runApp(MyApp(initialFavoriteIds: favoriteIds));
  }, (error, stack) {
    log('Uncaught zoned error:', error: error, stackTrace: stack);

    // ถ้า token หมดอายุ → เด้งกลับหน้า login
    if (error is UnauthorizedException) {
      AuthService.logout().then((_) =>
          navKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false));
      return;
    }

    // แจ้ง SnackBar หากมี context
    final context = navKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดไม่คาดคิด: $error')),
      );
    }
  });
}

/* ───────────── APP: DI + Theming + Routing ───────────── */
class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.initialFavoriteIds});
  final Set<int> initialFavoriteIds;

  @override
  Widget build(BuildContext context) {
    // 1) Base themes จากไฟล์ app_theme (ColorScheme ที่ถูกต้อง)
    final ThemeData baseLight = buildLightTheme();
    final ThemeData baseDark = buildDarkTheme();

    // 2) ตกแต่ง Base Theme → เพิ่มฟอนต์/คอมโพเนนต์เฉพาะแอป
    ThemeData withTypographyAndComponents(ThemeData base) {
      final cs = base.colorScheme;

      // — Typography: ใช้ GoogleFonts.itim + ขยายขนาดตามไกด์ —
      final textTheme = GoogleFonts.itimTextTheme(base.textTheme).copyWith(
        titleLarge: GoogleFonts.itim(
            fontSize: 24, fontWeight: FontWeight.bold, color: cs.onSurface),
        titleMedium: GoogleFonts.itim(
            fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface),
        bodyLarge: GoogleFonts.itim(
            fontSize: 18, fontWeight: FontWeight.w400, color: cs.onSurface),
        bodyMedium: GoogleFonts.itim(fontSize: 18, color: cs.onSurface),
        bodySmall: GoogleFonts.itim(fontSize: 16, color: cs.onSurface),
        // label ≥ 16sp ทั่วระบบ (ยกเว้นชิป)
        labelLarge: GoogleFonts.itim(
            fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
        labelMedium: GoogleFonts.itim(fontSize: 16, color: cs.onSurface),
        labelSmall: GoogleFonts.itim(fontSize: 16, color: cs.onSurface),
      );

      return base.copyWith(
        useMaterial3: true,
        textTheme: textTheme,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),

        // AppBar: สี/เงา/ตัวอักษร
        appBarTheme: base.appBarTheme.copyWith(
          elevation: 1,
          centerTitle: true,
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black26,
          titleTextStyle: textTheme.titleLarge,
        ),

        // ElevatedButton: ปุ่มหลักพื้นทึบ (minHeight 56)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: cs.primary,
            minimumSize: const Size(0, 46),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            textStyle:
                GoogleFonts.itim(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        // ★★ FilledButton: ให้เท่ากับ Elevated/Outlined → ปุ่มใน Dialog จะสูงเท่ากัน
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 46), // ← สำคัญ
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            textStyle:
                GoogleFonts.itim(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        // OutlinedButton: ปุ่มรองขอบเส้น (minHeight 56)
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.onSurface,
            minimumSize: const Size(0, 46),
            shape: const StadiumBorder(),
            side: BorderSide(color: cs.outline, width: 1.25), // คอนทราสต์พอดี
            padding: const EdgeInsets.symmetric(horizontal: 24),
            textStyle:
                GoogleFonts.itim(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        // TextButton: ปุ่มลิงก์/ตัวหนังสือ
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: cs.onSurfaceVariant,
            textStyle:
                GoogleFonts.itim(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),

        // Input: ฟอร์มกรอกต่าง ๆ
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: base.brightness == Brightness.light
              ? Colors.grey.shade100
              : cs.surfaceVariant.withOpacity(.25),
          hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.7)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: base.brightness == Brightness.light
                  ? Colors.grey.shade300
                  : cs.outlineVariant,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary, width: 2),
          ),
        ),

        // Card: การ์ดพื้นหลัง
        cardTheme: base.cardTheme.copyWith(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: cs.surface,
          shadowColor: Colors.black.withOpacity(0.08),
        ),

        // Chip: ป้ายกรอง/แท็ก → label 14 เพื่อบาลานซ์
        chipTheme: base.chipTheme.copyWith(
          shape: const StadiumBorder(),
          side: BorderSide(color: cs.primary.withOpacity(0.5)),
          backgroundColor: cs.primaryContainer.withOpacity(0.2),
          labelStyle: GoogleFonts.itim(
            fontSize: 14,
            color: cs.primary,
            fontWeight: FontWeight.bold,
          ),
        ),

        // BottomNav: แถบนำทางล่าง
        bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
          selectedItemColor: cs.primary,
          unselectedItemColor: cs.onSurfaceVariant,
          backgroundColor: cs.surface,
          elevation: 8,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.itim(
              fontWeight: FontWeight.bold, color: cs.onSurface),
          unselectedLabelStyle: GoogleFonts.itim(color: cs.onSurfaceVariant),
        ),

        // Dialog: มุมโค้งมาตรฐาน
        dialogTheme: base.dialogTheme.copyWith(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }

    // 3) สร้างธีม Light/Dark ที่ “แต่งแล้ว”
    final ThemeData appLight = withTypographyAndComponents(baseLight);
    final ThemeData appDark = withTypographyAndComponents(baseDark);

    // 4) Providers + MaterialApp
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => FavoriteStore(initialIds: initialFavoriteIds),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsStore()..load(),
        ),
      ],
      child: Consumer<SettingsStore>(
        builder: (_, settings, __) => MaterialApp(
          title: 'Cooking Guide',
          debugShowCheckedModeBanner: false,
          navigatorKey: navKey,
          navigatorObservers: [routeObserver],
          theme: appLight,
          darkTheme: appDark,
          themeMode: settings.themeMode, // ← ผูกกับ SettingsStore
          initialRoute: '/splash',
          onGenerateRoute: _onGenerateRoute,
          onUnknownRoute: (_) => MaterialPageRoute(
            builder: (_) => const ErrorPage(message: 'ไม่พบหน้าที่คุณเรียก'),
          ),
        ),
      ),
    );
  }

  /* ───────────── ROUTING: ศูนย์รวมเส้นทาง ───────────── */
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

      // ลืมรหัสผ่าน → ส่งอีเมลรับ OTP
      case '/reset_password':
        return _material(const ResetPasswordScreen(), settings);

      // ยืนยัน OTP (ลืมรหัสผ่าน)
      // ResetPasswordScreen → pushNamed('/verify_otp', arguments: email)
      case '/verify_otp':
        if (args is String) {
          return _material(OtpVerificationScreen(email: args), settings);
        }
        return _errorRoute('ข้อมูลอีเมลไม่ถูกต้อง');

      // ตั้งรหัสผ่านใหม่ (รับ email + otp)
      case '/new_password':
        if (args is Map<String, String>) {
          return _material(
            NewPasswordScreen(email: args['email']!, otp: args['otp']!),
            settings,
          );
        }
        return _errorRoute('ข้อมูล OTP ไม่ถูกต้อง');

      // ยืนยันอีเมลหลังสมัคร (คนละ flow)
      // RegisterScreen → pushReplacementNamed('/verify_email', arguments: email)
      case '/verify_email':
        if (args is String) {
          return _material(VerifyOtpScreen(email: args), settings);
        }
        return _errorRoute('ข้อมูลอีเมลไม่ถูกต้อง');

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
        return _material(
            const AuthGuard(child: edit_profile.EditProfileScreen()), settings);
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

  /* ───────────── HELPERS: รูปแบบทรานซิชันและ error route ───────────── */
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
