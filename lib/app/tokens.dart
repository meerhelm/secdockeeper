import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design-system tokens that don't fit neatly into [ColorScheme].
/// Read via `Theme.of(context).extension<AppColors>()!` or the helper
/// extension `BuildContext.appColors`.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.borderStrong,
    required this.fg,
    required this.fgStrong,
    required this.muted,
    required this.muted2,
    required this.accent,
    required this.accentFg,
    required this.accentSoft,
    required this.accentLine,
    required this.error,
    required this.errorSoft,
    required this.warn,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color borderStrong;
  final Color fg;
  final Color fgStrong;
  final Color muted;
  final Color muted2;
  final Color accent;
  final Color accentFg;
  final Color accentSoft;
  final Color accentLine;
  final Color error;
  final Color errorSoft;
  final Color warn;

  static const dark = AppColors(
    bg: Color(0xFF050507),
    surface: Color(0xFF0E0E10),
    surface2: Color(0xFF16161A),
    surface3: Color(0xFF1D1D22),
    border: Color(0xFF2A2A2C),
    borderStrong: Color(0xFF3D3A39),
    fg: Color(0xFFF2F2F2),
    fgStrong: Color(0xFFFFFFFF),
    muted: Color(0xFF8E8E93),
    muted2: Color(0xFF5B5B60),
    accent: Color(0xFF00D992),
    accentFg: Color(0xFF032D20),
    accentSoft: Color(0x1F00D992), // 12% alpha
    accentLine: Color(0x4D00D992), // 30% alpha
    error: Color(0xFFFF5F5F),
    errorSoft: Color(0x1AFF5F5F), // 10% alpha
    warn: Color(0xFFFFBA00),
  );

  static const light = AppColors(
    bg: Color(0xFFF7F7F5),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEFEEEC),
    surface3: Color(0xFFE6E5E1),
    border: Color(0xFFE2E1DE),
    borderStrong: Color(0xFFC8C6C1),
    fg: Color(0xFF16161A),
    fgStrong: Color(0xFF050507),
    muted: Color(0xFF6B6B70),
    muted2: Color(0xFF9A999D),
    accent: Color(0xFF047857),
    accentFg: Color(0xFFFFFFFF),
    accentSoft: Color(0x1A047857), // 10% alpha
    accentLine: Color(0x57047857), // 34% alpha
    error: Color(0xFFD23036),
    errorSoft: Color(0x12D23036), // 7% alpha
    warn: Color(0xFFB07A00),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? border,
    Color? borderStrong,
    Color? fg,
    Color? fgStrong,
    Color? muted,
    Color? muted2,
    Color? accent,
    Color? accentFg,
    Color? accentSoft,
    Color? accentLine,
    Color? error,
    Color? errorSoft,
    Color? warn,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      fg: fg ?? this.fg,
      fgStrong: fgStrong ?? this.fgStrong,
      muted: muted ?? this.muted,
      muted2: muted2 ?? this.muted2,
      accent: accent ?? this.accent,
      accentFg: accentFg ?? this.accentFg,
      accentSoft: accentSoft ?? this.accentSoft,
      accentLine: accentLine ?? this.accentLine,
      error: error ?? this.error,
      errorSoft: errorSoft ?? this.errorSoft,
      warn: warn ?? this.warn,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      fgStrong: Color.lerp(fgStrong, other.fgStrong, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      muted2: Color.lerp(muted2, other.muted2, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentFg: Color.lerp(accentFg, other.accentFg, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentLine: Color.lerp(accentLine, other.accentLine, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorSoft: Color.lerp(errorSoft, other.errorSoft, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}

/// Mono text styling — used for meta lines, file sizes, dates, hashes, labels.
/// Uses JetBrains Mono via google_fonts.
class AppMono {
  AppMono._();

  static TextStyle of(BuildContext context, {
    double size = 11,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      color: color ?? context.c.fg,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Uppercase mono label — section headers, labels above inputs, etc.
  static TextStyle label(BuildContext context, {Color? color, double size = 10}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      color: color ?? context.c.muted,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.16 * size,
    );
  }

  /// Meta line styling (file size · time, etc.)
  static TextStyle meta(BuildContext context, {Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: 10.5,
      color: color ?? context.c.muted,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.21,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
