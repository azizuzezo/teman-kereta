import 'package:flutter/material.dart';

import 'tk_colors.dart';

export 'tk_colors.dart';

/// Legacy constants kept only so screens that have not migrated to
/// `context.tk` still compile. New code must not use these.
abstract final class AppColors {
  static const navy = Color(0xFF17376B);
  static const blue = Color(0xFF1259C8);
  static const softBlue = Color(0xFFE1EAF7);
  static const coral = Color(0xFFC81E28);
  static const success = Color(0xFF0F7A50);
  static const warning = Color(0xFF8F4F00);
  static const error = Color(0xFFB91C25);
  static const backgroundLight = Color(0xFFF3F5F9);
  static const surfaceLight = Color(0xFFFCFDFE);
  static const textPrimary = Color(0xFF0E2038);
  static const textSecondary = Color(0xFF47596F);
  static const border = Color(0xFFD5DDE8);
  static const backgroundDark = Color(0xFF0A111D);
  static const surfaceDark = Color(0xFF111B2B);
  static const elevatedDark = Color(0xFF182539);
  static const textPrimaryDark = Color(0xFFE6EDF7);
  static const textSecondaryDark = Color(0xFF9DB0C8);
  static const borderDark = Color(0xFF263650);
}

/// Radii shared by every surface so shapes stay consistent.
abstract final class TkRadius {
  static const card = 20.0;
  static const control = 14.0;
  static const sheet = 28.0;
}

abstract final class AppTheme {
  static ThemeData light([TkPaletteId palette = TkPaletteId.navyKrl]) =>
      _build(Brightness.light, TkPalettes.byId(palette));

  static ThemeData dark([TkPaletteId palette = TkPaletteId.navyKrl]) =>
      _build(Brightness.dark, TkPalettes.byId(palette));

  /// Tabular figures keep times and countdowns from jittering as digits change.
  static const timeFeatures = <FontFeature>[FontFeature.tabularFigures()];

  static ThemeData _build(Brightness brightness, TkPalette palette) {
    final tk = palette.forBrightness(brightness);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: tk.primary,
      onPrimary: tk.onPrimary,
      primaryContainer: tk.primarySoft,
      onPrimaryContainer: tk.primary,
      secondary: tk.accent,
      onSecondary: tk.onAccent,
      // Tonal buttons and chips read from secondaryContainer. They must stay
      // in the brand hue: red is reserved for accents and destructive actions.
      secondaryContainer: tk.primarySoft,
      onSecondaryContainer: tk.primary,
      tertiary: tk.success,
      onTertiary: tk.onPrimary,
      error: tk.danger,
      onError: tk.isDark ? const Color(0xFF2A0709) : const Color(0xFFFFFFFF),
      errorContainer: tk.dangerSoft,
      onErrorContainer: tk.danger,
      surface: tk.surface,
      onSurface: tk.text,
      onSurfaceVariant: tk.textMuted,
      surfaceContainerLowest: tk.bg,
      surfaceContainerLow: tk.bg,
      surfaceContainer: tk.surfaceAlt,
      surfaceContainerHigh: tk.surfaceAlt,
      surfaceContainerHighest: tk.surfaceAlt,
      outline: tk.border,
      outlineVariant: tk.border,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: tk.text,
      onInverseSurface: tk.bg,
      inversePrimary: tk.primarySoft,
    );

    final baseText = ThemeData(
      brightness: brightness,
      fontFamily: 'PlusJakartaSans',
    ).textTheme.apply(bodyColor: tk.text, displayColor: tk.text);

    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        fontSize: 34,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
      ),
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontSize: 28,
        height: 1.18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontSize: 24,
        height: 1.22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: baseText.titleSmall?.copyWith(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16, height: 1.55),
      bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      bodySmall: baseText.bodySmall?.copyWith(
        fontSize: 12.5,
        height: 1.45,
        color: tk.textMuted,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: baseText.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: tk.textMuted,
      ),
    );

    RoundedRectangleBorder shape(double radius) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(TkRadius.control),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'PlusJakartaSans',
      scaffoldBackgroundColor: tk.bg,
      canvasColor: tk.bg,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[tk],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: tk.bg,
        foregroundColor: tk.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: tk.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TkRadius.card),
          side: BorderSide(color: tk.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: shape(TkRadius.control),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: tk.text,
          side: BorderSide(color: tk.border),
          shape: shape(TkRadius.control),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: tk.primary,
          shape: shape(TkRadius.control),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: tk.text,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tk.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: tk.textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: tk.textMuted),
        floatingLabelStyle: textTheme.labelLarge?.copyWith(color: tk.primary),
        border: inputBorder(tk.border),
        enabledBorder: inputBorder(tk.border),
        focusedBorder: inputBorder(tk.primary, 2),
        errorBorder: inputBorder(tk.danger),
        focusedErrorBorder: inputBorder(tk.danger, 2),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: tk.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: tk.primarySoft,
        indicatorShape: shape(14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? tk.primary
                : tk.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? tk.primary
                : tk.textMuted,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tk.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: tk.textMuted,
        textColor: tk.text,
        shape: shape(TkRadius.control),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tk.surfaceAlt,
        selectedColor: tk.primarySoft,
        side: BorderSide(color: tk.border),
        labelStyle: textTheme.labelLarge?.copyWith(color: tk.text),
        shape: const StadiumBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? tk.onPrimary : tk.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? tk.primary : tk.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : tk.border,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: tk.surface,
          foregroundColor: tk.text,
          selectedBackgroundColor: tk.primarySoft,
          selectedForegroundColor: tk.primary,
          side: BorderSide(color: tk.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tk.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TkRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tk.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape(TkRadius.sheet),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tk.text,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: tk.bg),
        shape: shape(TkRadius.control),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tk.primary,
        linearTrackColor: tk.surfaceAlt,
      ),
    );
  }
}
