import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

/// Central dark theme for OmniTune, built on the brand palette.
abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.coral,
      onPrimary: Colors.white,
      secondary: AppColors.sky,
      onSecondary: AppColors.charcoal,
      tertiary: AppColors.cyan,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.card,
      error: Color(0xFFE5484D),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      dividerColor: AppColors.divider,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.coral,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl, vertical: AppDimens.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 4,
        activeTrackColor: AppColors.coral,
        inactiveTrackColor: AppColors.divider,
        thumbColor: AppColors.coral,
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        isDense: true,
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          borderSide: const BorderSide(color: AppColors.coral, width: 1.4),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        selectedColor: AppColors.coral,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.sidebar,
        selectedItemColor: AppColors.coral,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.card,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
