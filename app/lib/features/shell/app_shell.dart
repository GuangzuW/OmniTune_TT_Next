import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimens.dart';
import 'package:app/features/player/mini_player.dart';
import 'package:app/features/shared/offline_banner.dart';

class _Dest {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _Dest(this.icon, this.activeIcon, this.label);
}

const _destinations = [
  _Dest(Icons.home_outlined, Icons.home_rounded, 'Home'),
  _Dest(Icons.search_outlined, Icons.search_rounded, 'Search'),
  _Dest(Icons.library_music_outlined, Icons.library_music_rounded, 'Library'),
  _Dest(Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
];

/// Responsive scaffold: sidebar (desktop) or bottom nav (mobile), with the
/// persistent mini-player above the nav. Wraps the go_router StatefulShell.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  void _go(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final mobile = AppDimens.isMobile(context);
    final current = navigationShell.currentIndex;

    if (mobile) {
      return Scaffold(
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: navigationShell),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            BottomNavigationBar(
              currentIndex: current,
              onTap: _go,
              items: [
                for (final d in _destinations)
                  BottomNavigationBarItem(
                      icon: Icon(d.icon), activeIcon: Icon(d.activeIcon), label: d.label),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(current: current, onSelect: _go),
          Expanded(
            child: Column(
              children: [
                const OfflineBanner(),
                Expanded(child: navigationShell),
                const MiniPlayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onSelect;
  const _Sidebar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimens.sidebarWidth,
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppDimens.xl, AppDimens.xl, AppDimens.xl, AppDimens.lg),
            child: Row(
              children: [
                Icon(Icons.graphic_eq_rounded, color: AppColors.coral),
                SizedBox(width: AppDimens.sm),
                Text('OmniTune',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ],
            ),
          ),
          for (var i = 0; i < _destinations.length; i++)
            _SidebarItem(
              dest: _destinations[i],
              selected: i == current,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(AppDimens.lg),
            child: Text('v1.0', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarItem({required this.dest, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: 2),
      child: Material(
        color: selected ? AppColors.coral.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: AppDimens.md),
            child: Row(
              children: [
                Icon(selected ? dest.activeIcon : dest.icon,
                    color: selected ? AppColors.coral : AppColors.textSecondary, size: 22),
                const SizedBox(width: AppDimens.md),
                Text(dest.label,
                    style: TextStyle(
                        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
