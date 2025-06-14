// lib/main.dart

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/splash_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'models/recipe.dart';

// RouteObserver สำหรับใช้ตรวจจับการเปลี่ยนหน้า
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th', null);
  runApp(const CookingGuideApp());
}

class CookingGuideApp extends StatelessWidget {
  const CookingGuideApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFFFF9B05);

    return MaterialApp(
      title: 'Cooking Guide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primary,
        colorScheme: ColorScheme.light(
          primary: primary,
          secondary: primary,
        ),
        scaffoldBackgroundColor: Colors.white,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: primary, width: 1.5),
          ),
        ),
      ),

      // ติดตั้ง RouteObserver เพื่อตรวจจับการนำทาง
      navigatorObservers: [routeObserver],

      home: const SplashScreen(),

      routes: {
        '/recipe_detail': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments;
          if (args is Recipe) {
            return RecipeDetailScreen(recipeId: args.id);
          }
          return const Scaffold(body: Center(child: Text('ข้อมูลไม่ถูกต้อง')));
        },
      },
    );
  }
}
