import 'package:flutter/material.dart';

/// OmniTune brand palette ("Advanced Sense" color matching), dark-first.
///
///  charcoal  #252C38  app background base
///  navy      #213271  elevated surfaces (sidebar, cards, sheets)
///  sky       #8FB9D1  secondary text / inactive icons / subtle accents
///  cyan      #DDFAFB  highlights / hover / light surface
///  coral     #E86349  PRIMARY action: play, CTAs, active state, progress
abstract final class AppColors {
  // Brand
  static const Color navy = Color(0xFF213271);
  static const Color sky = Color(0xFF8FB9D1);
  static const Color cyan = Color(0xFFDDFAFB);
  static const Color coral = Color(0xFFE86349);
  static const Color charcoal = Color(0xFF252C38);

  // Derived layers (dark theme)
  static const Color bg = Color(0xFF1B212B); // lowest scaffold layer
  static const Color surface = charcoal; // base surface
  static const Color surfaceElevated = Color(0xFF2E3644); // cards/rows hover
  static const Color sidebar = Color(0xFF1E2840); // navy-tinted nav rail
  static const Color card = Color(0xFF243049); // navy-charcoal blend for cards

  // Text
  static const Color textPrimary = Color(0xFFF2F5F8);
  static const Color textSecondary = sky;
  static const Color textTertiary = Color(0xFF6B7686);

  // States
  static const Color coralDark = Color(0xFFC94F38); // pressed
  static const Color divider = Color(0xFF333C4A);

  // Accent gradient (used on hero / now-playing backdrops)
  static const List<Color> heroGradient = [navy, charcoal];
}
