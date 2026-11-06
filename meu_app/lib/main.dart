import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openfoodfacts/openfoodfacts.dart' as off;
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'core/app_theme.dart';

part 'models/app_user.dart';
part 'models/catalog_product.dart';
part 'models/product.dart';

part 'widgets/common_widgets.dart';

part 'screens/about_screen.dart';
part 'screens/account_screen.dart';
part 'screens/chefim_shell.dart';
part 'screens/home_screen.dart';
part 'screens/login_screen.dart';
part 'screens/pantry_screen.dart';
part 'screens/privacy_policy_screen.dart';
part 'screens/profile_screen.dart';
part 'screens/recipe_search_screen.dart';
part 'screens/recipes_screen.dart';
part 'screens/register_screen.dart';
part 'screens/scanner_screen.dart';
part 'screens/settings_screen.dart';
part 'screens/shopping_list_screen.dart';
part 'screens/splash_screen.dart';
part 'screens/terms_screen.dart';

part 'services/barcode_parser_service.dart';
part 'services/database_service.dart';
part 'services/label_ocr_service.dart';
part 'services/password_service.dart';
part 'services/preferences_service.dart';
part 'services/product_catalog_service.dart';
part 'services/supabase_catalog_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _configureOpenFoodFacts();

  await SupabaseCatalogService.initialize();
  await _restorePreferences();

  runApp(const ChefimApp());
}

/// Configura a identificação do aplicativo nas consultas feitas ao
/// Open Food Facts.
void _configureOpenFoodFacts() {
  off.OpenFoodAPIConfiguration.userAgent = off.UserAgent(
    name: 'Chefim',
    url: 'https://github.com/Marcio-Gazzinelli/chefim-app',
  );

  off.OpenFoodAPIConfiguration.globalLanguages = const [
    off.OpenFoodFactsLanguage.PORTUGUESE,
  ];
}

/// Recupera as preferências salvas.
///
/// Caso ocorra algum problema na leitura, o aplicativo inicia no modo claro.
Future<void> _restorePreferences() async {
  try {
    nightMode.value = await PreferencesService.instance.getNightMode();
  } catch (_) {
    nightMode.value = false;
  }
}

class ChefimApp extends StatelessWidget {
  const ChefimApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Roboto',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: nightMode,
      builder: (context, isNight, child) {
        final brightness = isNight ? Brightness.dark : Brightness.light;

        return MaterialApp(
          title: 'Chefim',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(brightness),
          home: const SplashScreen(),
        );
      },
    );
  }
}
