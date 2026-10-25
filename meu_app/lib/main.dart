import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

part 'core/app_theme.dart';
part 'models/app_user.dart';
part 'models/product.dart';
part 'widgets/common_widgets.dart';
part 'screens/chefim_shell.dart';
part 'screens/home_screen.dart';
part 'screens/pantry_screen.dart';
part 'screens/recipes_screen.dart';
part 'screens/profile_screen.dart';
part 'screens/account_screen.dart';
part 'screens/register_screen.dart';
part 'screens/login_screen.dart';
part 'screens/shopping_list_screen.dart';
part 'screens/about_screen.dart';
part 'screens/terms_screen.dart';
part 'screens/privacy_policy_screen.dart';
part 'screens/settings_screen.dart';
part 'screens/recipe_search_screen.dart';
part 'screens/scanner_screen.dart';
part 'services/preferences_service.dart';
part 'services/database_service.dart';
part 'services/password_service.dart';
part 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  nightMode.value = await PreferencesService.instance.getNightMode();

  runApp(const ChefimApp());
}

class ChefimApp extends StatelessWidget {
  const ChefimApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: nightMode,
    builder: (context, isNight, _) => MaterialApp(
      title: 'Chefim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          brightness: isNight ? Brightness.dark : Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    ),
  );
}
