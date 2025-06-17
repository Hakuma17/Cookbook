import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/splash_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/my_recipes_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'models/recipe.dart';

// RouteObserver สำหรับใช้ตรวจจับการเปลี่ยนหน้า
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th', null);
  runApp(const CookingGuideApp());
}

class CookingGuideApp extends StatelessWidget {
  const CookingGuideApp({Key? key}) : super(key: key);

  static const _primaryColor = Color(0xFFFF9B05);

  ThemeData _buildTheme() {
    return ThemeData(
      primaryColor: _primaryColor,
      colorScheme: ColorScheme.light(
        primary: _primaryColor,
        secondary: _primaryColor,
      ),
      scaffoldBackgroundColor: Colors.white,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          side: const BorderSide(color: _primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // หน้า Login (เรียกเมื่อยังไม่ล็อกอินหรือกดไอคอน)
      case '/login':
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      // รายละเอียดสูตร
      case '/recipe_detail':
        final args = settings.arguments;
        if (args is Recipe) {
          return MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipeId: args.id),
            settings: settings,
          );
        }
        return _errorRoute('ข้อมูล recipe ไม่ถูกต้อง');

      // หน้าคลังของฉัน (My Recipes) พร้อมตรวจล็อกอิน
      case '/myrecipes':
        // รับ argument เป็นเลขแท็บ (0=Favorites, 1=Cart) ถ้าไม่มี default=0
        final tab = settings.arguments is int ? settings.arguments as int : 0;
        return MaterialPageRoute(
          builder: (_) => AuthGuard(
            child: MyRecipesScreen(initialTab: tab),
          ),
          settings: settings,
        );

      default:
        return null; // ให้ไปใช้ home หรือ onUnknownRoute
    }
  }

  Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(child: Text(message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cooking Guide',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      navigatorObservers: [routeObserver],
      home: const SplashScreen(),
      onGenerateRoute: _onGenerateRoute,
      onUnknownRoute: (settings) => _errorRoute('หน้าไม่พบ'),
    );
  }
}

/// ตรวจสถานะล็อกอินก่อนแสดง child widget
class AuthGuard extends StatelessWidget {
  final Widget child;
  const AuthGuard({required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          // ถ้าล็อกอินแล้ว แสดง child
          return child;
        }
        // ยังไม่ล็อกอิน → ไปหน้า Login
        return const LoginScreen();
      },
    );
  }
}
