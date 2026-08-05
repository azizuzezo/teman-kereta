/* Hallmark · macrostructure: Workbench · tone: friendly-utilitarian · anchor hue: rail-blue
 * theme: TK user-specified · enrichment: code-native rail diagram
 * pre-emit critique: P5 H4 E4 S5 R5 V4
 */
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF102A43);
  static const blue = Color(0xFF1677FF);
  static const softBlue = Color(0xFFEAF3FF);
  static const coral = Color(0xFFFF5A5F);
  static const success = Color(0xFF16A36A);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFD92D20);
  static const backgroundLight = Color(0xFFF7F9FC);
  static const surfaceLight = Color(0xFFFFFEFC);
  static const textPrimary = Color(0xFF172B4D);
  static const textSecondary = Color(0xFF52677D);
  static const border = Color(0xFFDCE3EC);
  static const backgroundDark = Color(0xFF09131F);
  static const surfaceDark = Color(0xFF112235);
  static const elevatedDark = Color(0xFF183149);
  static const textPrimaryDark = Color(0xFFF5F8FC);
  static const textSecondaryDark = Color(0xFFB9C7D6);
  static const borderDark = Color(0xFF29445D);
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final text = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final muted = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final border = isDark ? AppColors.borderDark : AppColors.border;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.blue,
      onPrimary: const Color(0xFFF8FBFF),
      secondary: AppColors.coral,
      onSecondary: AppColors.navy,
      error: AppColors.error,
      onError: const Color(0xFFFFF8F7),
      surface: surface,
      onSurface: text,
      outline: border,
      outlineVariant: border,
      surfaceContainerHighest: isDark
          ? AppColors.elevatedDark
          : AppColors.softBlue,
    );

    final baseText = ThemeData(
      brightness: brightness,
      fontFamily: 'PlusJakartaSans',
    ).textTheme.apply(bodyColor: text, displayColor: text);

    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16, height: 1.55),
      bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      bodySmall: baseText.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.45,
        color: muted,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'PlusJakartaSans',
      scaffoldBackgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.blue),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: isDark ? AppColors.elevatedDark : AppColors.softBlue,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
