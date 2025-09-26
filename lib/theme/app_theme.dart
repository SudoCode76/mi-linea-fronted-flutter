import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_extensions.dart';

enum ThemePreference { system, light, dark }

class AppThemeController extends ChangeNotifier {
  ThemePreference _pref = ThemePreference.system;
  ThemePreference get preference => _pref;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('theme_pref');
    if (raw != null) {
      _pref = ThemePreference.values.firstWhere(
            (e) => e.toString() == raw,
        orElse: () => ThemePreference.system,
      );
      notifyListeners();
    }
  }

  Future<void> setPreference(ThemePreference p) async {
    _pref = p;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString('theme_pref', p.toString());
  }
}

class AppTheme {
  static ThemeMode toThemeMode(ThemePreference p) {
    switch (p) {
      case ThemePreference.system:
        return ThemeMode.system;
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  static ThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF007AFF),
      brightness: brightness,
    );

    // Ajuste de superficies para mejor contraste
    final scheme = baseScheme.copyWith(
      surface: isDark ? const Color(0xFF14161B) : const Color(0xFFF5F7FB),
      surfaceContainerHighest:
      isDark ? const Color(0xFF272A31) : Colors.white,
      surfaceVariant:
      isDark ? const Color(0xFF3A3F47) : const Color(0xFFE2E6EC),
      primaryContainer: isDark
          ? const Color(0xFF2F5FAA)
          : baseScheme.primaryContainer, // para tabs activos/chat
      onPrimaryContainer:
      isDark ? Colors.white : baseScheme.onPrimaryContainer,
    );

    final shapes = AppShapes.defaults();
    final spacing = AppSpacing.defaults();
    final durations = AppDurations.defaults();
    final glass = isDark ? AppGlass.dark() : AppGlass.light();

    final baseTextTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    ).textTheme;

    final textTheme = baseTextTheme.copyWith(
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.radiusLg),
        ),
        margin: const EdgeInsets.all(8),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.radiusLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(shapes.radiusXl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceVariant.withValues(alpha: .32)
            : Colors.black.withValues(alpha: .04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.radiusMd),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: .24)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.radiusMd),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: .18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shapes.radiusMd),
          ),
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm + 2,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      extensions: [
        shapes,
        spacing,
        durations,
        glass,
      ],
    );
  }
}