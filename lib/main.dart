import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;

import 'app_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final themeController = AppThemeController();
  await themeController.load();

  try {
    final perm = await geo.Geolocator.checkPermission();
    if (perm == geo.LocationPermission.denied) {
      await geo.Geolocator.requestPermission();
    }
  } catch (_) {}

  runApp(App(themeController: themeController));
}

class App extends StatelessWidget {
  final AppThemeController themeController;
  const App({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        // Para el modo system usamos el ThemeMode + darkTheme opcional
        final mode = AppTheme.toThemeMode(themeController.preference);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: AppTheme.build(Brightness.light),
          darkTheme: AppTheme.build(Brightness.dark),
          home: AppShell(themeController: themeController),
        );
      },
    );
  }
}