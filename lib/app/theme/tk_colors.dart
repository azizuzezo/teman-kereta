import 'package:flutter/material.dart';

/// Semantic color tokens. Every screen reads colors from here through
/// `context.tk`, never from raw hex values, so palette + light/dark switching
/// reaches every widget.
@immutable
class TkColors extends ThemeExtension<TkColors> {
  const TkColors({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  bool get isDark => brightness == Brightness.dark;

  @override
  TkColors copyWith({
    Brightness? brightness,
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
  }) {
    return TkColors(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
    );
  }

  @override
  TkColors lerp(ThemeExtension<TkColors>? other, double t) {
    if (other is! TkColors) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return TkColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      surfaceAlt: mix(surfaceAlt, other.surfaceAlt),
      border: mix(border, other.border),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primarySoft: mix(primarySoft, other.primarySoft),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentSoft: mix(accentSoft, other.accentSoft),
      success: mix(success, other.success),
      successSoft: mix(successSoft, other.successSoft),
      warning: mix(warning, other.warning),
      warningSoft: mix(warningSoft, other.warningSoft),
      danger: mix(danger, other.danger),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
    );
  }
}

extension TkColorsContext on BuildContext {
  /// Tokens of the active theme. Falls back to the default palette when a
  /// bare `ThemeData` (e.g. in a widget test) has no extension installed.
  TkColors get tk {
    final theme = Theme.of(this);
    return theme.extension<TkColors>() ??
        TkPalettes.byId(TkPaletteId.navyKrl).forBrightness(theme.brightness);
  }
}

enum TkPaletteId { navyKrl, biruKlasik, hijauStasiun }

class TkPalette {
  const TkPalette({
    required this.id,
    required this.label,
    required this.description,
    required this.light,
    required this.dark,
  });

  final TkPaletteId id;
  final String label;
  final String description;
  final TkColors light;
  final TkColors dark;

  TkColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

abstract final class TkPalettes {
  static const all = <TkPalette>[_navyKrl, _biruKlasik, _hijauStasiun];

  static TkPalette byId(TkPaletteId id) =>
      all.firstWhere((palette) => palette.id == id);

  static TkPaletteId decode(String? name) =>
      TkPaletteId.values.where((id) => id.name == name).firstOrNull ??
      TkPaletteId.navyKrl;

  // Neutrals are shared per mode; only brand + accent differ per palette.
  // Contrast of every text/background pair was verified >= WCAG AA 4.5:1.
  static const _lightBg = Color(0xFFF3F5F9);
  static const _lightSurface = Color(0xFFFCFDFE);
  static const _lightAlt = Color(0xFFE8EDF4);
  static const _lightBorder = Color(0xFFD5DDE8);
  static const _lightText = Color(0xFF0E2038);
  static const _lightMuted = Color(0xFF47596F);

  static const _darkBg = Color(0xFF0A111D);
  static const _darkSurface = Color(0xFF111B2B);
  static const _darkAlt = Color(0xFF182539);
  static const _darkBorder = Color(0xFF263650);
  static const _darkText = Color(0xFFE6EDF7);
  static const _darkMuted = Color(0xFF9DB0C8);

  static const _navyKrl = TkPalette(
    id: TkPaletteId.navyKrl,
    label: 'Navy KRL',
    description: 'Navy dan merah dari logo',
    light: TkColors(
      brightness: Brightness.light,
      bg: _lightBg,
      surface: _lightSurface,
      surfaceAlt: _lightAlt,
      border: _lightBorder,
      text: _lightText,
      textMuted: _lightMuted,
      primary: Color(0xFF17376B),
      onPrimary: Color(0xFFFFFFFF),
      primarySoft: Color(0xFFE1EAF7),
      accent: Color(0xFFC81E28),
      onAccent: Color(0xFFFFFFFF),
      accentSoft: Color(0xFFFBE4E5),
      success: Color(0xFF0F7A50),
      successSoft: Color(0xFFDDF1E8),
      warning: Color(0xFF8F4F00),
      warningSoft: Color(0xFFFFF1DB),
      danger: Color(0xFFB91C25),
      dangerSoft: Color(0xFFFBE4E5),
    ),
    dark: TkColors(
      brightness: Brightness.dark,
      bg: _darkBg,
      surface: _darkSurface,
      surfaceAlt: _darkAlt,
      border: _darkBorder,
      text: _darkText,
      textMuted: _darkMuted,
      primary: Color(0xFF8DB2F2),
      onPrimary: Color(0xFF0A1830),
      primarySoft: Color(0xFF172A4A),
      accent: Color(0xFFFF7773),
      onAccent: Color(0xFF2A0709),
      accentSoft: Color(0xFF3A1A1F),
      success: Color(0xFF4CD39B),
      successSoft: Color(0xFF0F2E23),
      warning: Color(0xFFF5B74A),
      warningSoft: Color(0xFF33260E),
      danger: Color(0xFFFF8A8A),
      dangerSoft: Color(0xFF3A1A1F),
    ),
  );

  static const _biruKlasik = TkPalette(
    id: TkPaletteId.biruKlasik,
    label: 'Biru Klasik',
    description: 'Biru terang dan koral, tema lama',
    light: TkColors(
      brightness: Brightness.light,
      bg: _lightBg,
      surface: _lightSurface,
      surfaceAlt: _lightAlt,
      border: _lightBorder,
      text: _lightText,
      textMuted: _lightMuted,
      primary: Color(0xFF1259C8),
      onPrimary: Color(0xFFFFFFFF),
      primarySoft: Color(0xFFE3EEFD),
      accent: Color(0xFFBF262B),
      onAccent: Color(0xFFFFFFFF),
      accentSoft: Color(0xFFFBE6E6),
      success: Color(0xFF0F7A50),
      successSoft: Color(0xFFDDF1E8),
      warning: Color(0xFF8F4F00),
      warningSoft: Color(0xFFFFF1DB),
      danger: Color(0xFFB91C25),
      dangerSoft: Color(0xFFFBE4E5),
    ),
    dark: TkColors(
      brightness: Brightness.dark,
      bg: _darkBg,
      surface: _darkSurface,
      surfaceAlt: _darkAlt,
      border: _darkBorder,
      text: _darkText,
      textMuted: _darkMuted,
      primary: Color(0xFF7DB1FF),
      onPrimary: Color(0xFF071A33),
      primarySoft: Color(0xFF14294A),
      accent: Color(0xFFFF8084),
      onAccent: Color(0xFF2A0709),
      accentSoft: Color(0xFF3A1A1F),
      success: Color(0xFF4CD39B),
      successSoft: Color(0xFF0F2E23),
      warning: Color(0xFFF5B74A),
      warningSoft: Color(0xFF33260E),
      danger: Color(0xFFFF8A8A),
      dangerSoft: Color(0xFF3A1A1F),
    ),
  );

  static const _hijauStasiun = TkPalette(
    id: TkPaletteId.hijauStasiun,
    label: 'Hijau Stasiun',
    description: 'Hijau tua dan oranye bata',
    light: TkColors(
      brightness: Brightness.light,
      bg: _lightBg,
      surface: _lightSurface,
      surfaceAlt: _lightAlt,
      border: _lightBorder,
      text: _lightText,
      textMuted: _lightMuted,
      primary: Color(0xFF0B6347),
      onPrimary: Color(0xFFFFFFFF),
      primarySoft: Color(0xFFDDF1E8),
      accent: Color(0xFF9A4308),
      onAccent: Color(0xFFFFFFFF),
      accentSoft: Color(0xFFFBEBD6),
      success: Color(0xFF0F7A50),
      successSoft: Color(0xFFDDF1E8),
      warning: Color(0xFF8F4F00),
      warningSoft: Color(0xFFFFF1DB),
      danger: Color(0xFFB91C25),
      dangerSoft: Color(0xFFFBE4E5),
    ),
    dark: TkColors(
      brightness: Brightness.dark,
      bg: _darkBg,
      surface: _darkSurface,
      surfaceAlt: _darkAlt,
      border: _darkBorder,
      text: _darkText,
      textMuted: _darkMuted,
      primary: Color(0xFF6FD3AE),
      onPrimary: Color(0xFF04241A),
      primarySoft: Color(0xFF123B2E),
      accent: Color(0xFFF2A154),
      onAccent: Color(0xFF2A1503),
      accentSoft: Color(0xFF3A2A15),
      success: Color(0xFF4CD39B),
      successSoft: Color(0xFF0F2E23),
      warning: Color(0xFFF5B74A),
      warningSoft: Color(0xFF33260E),
      danger: Color(0xFFFF8A8A),
      dangerSoft: Color(0xFF3A1A1F),
    ),
  );
}
