import 'package:flutter/widgets.dart';

/// Spacing, radius and layout tokens. Keeps the UI consistent across screens.
abstract final class AppDimens {
  // Spacing scale (4pt grid)
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // Radii
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 16;
  static const double radiusPill = 999;

  // Layout
  static const double sidebarWidth = 232;
  static const double miniPlayerHeight = 72;
  static const double cardSize = 168;

  // Responsive breakpoint: below this we use bottom nav (mobile), above = sidebar.
  static const double mobileBreakpoint = 760;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;
}
