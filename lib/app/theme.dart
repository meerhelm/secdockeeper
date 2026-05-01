import 'package:flutter/material.dart';

import 'tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.accentFg,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.accent,
      secondary: c.accent,
      onSecondary: c.accentFg,
      secondaryContainer: c.accentSoft,
      onSecondaryContainer: c.accent,
      tertiary: c.accent,
      onTertiary: c.accentFg,
      tertiaryContainer: c.accentSoft,
      onTertiaryContainer: c.accent,
      error: c.error,
      onError: brightness == Brightness.dark
          ? const Color(0xFF2A0808)
          : Colors.white,
      errorContainer: c.errorSoft,
      onErrorContainer: c.error,
      surface: c.bg,
      onSurface: c.fg,
      onSurfaceVariant: c.muted,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface2,
      surfaceContainerHighest: c.surface3,
      outline: c.border,
      outlineVariant: c.borderStrong,
      shadow: Colors.black,
      scrim: Colors.black.withValues(alpha: 0.55),
      inverseSurface: c.fg,
      onInverseSurface: c.bg,
      inversePrimary: c.accent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      visualDensity: VisualDensity.standard,
      splashFactory: NoSplash.splashFactory,
      extensions: [c],
    );

    final textTheme = base.textTheme.apply(
      bodyColor: c.fg,
      displayColor: c.fg,
    ).copyWith(
      displayLarge: TextStyle(
        fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -0.6,
        height: 1.05, color: c.fg,
      ),
      headlineLarge: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.5,
        height: 1.1, color: c.fg,
      ),
      headlineMedium: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.34,
        height: 1.15, color: c.fg,
      ),
      headlineSmall: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.22,
        color: c.fg,
      ),
      titleLarge: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.31,
        color: c.fg,
      ),
      titleMedium: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2,
        color: c.fg,
      ),
      titleSmall: TextStyle(
        fontSize: 14.5, fontWeight: FontWeight.w500,
        letterSpacing: -0.07, color: c.fg,
      ),
      bodyLarge: TextStyle(
        fontSize: 15, height: 1.5, color: c.fg,
      ),
      bodyMedium: TextStyle(
        fontSize: 14, height: 1.5, color: c.muted,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5, height: 1.45, color: c.muted,
      ),
      labelLarge: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.07,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.fg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: c.fg),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: c.border, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.accentFg,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.fg,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: c.borderStrong, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.fg,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.accentFg,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedTextStyle: textTheme.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: textTheme.bodyLarge?.copyWith(color: c.muted2),
        labelStyle: textTheme.bodyMedium,
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accentLine, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.error, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        side: BorderSide(color: c.border, width: 1),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: c.fg, fontWeight: FontWeight.w500, fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: c.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        modalBarrierColor: Colors.black.withValues(alpha: 0.55),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface2,
        contentTextStyle: textTheme.bodySmall?.copyWith(color: c.fg),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.border, width: 1),
        ),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: c.border, width: 1),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: c.borderStrong, width: 1.5),
        fillColor: WidgetStatePropertyAll(c.accent),
        checkColor: WidgetStatePropertyAll(c.accentFg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
