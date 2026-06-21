import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:app/features/home/home_screen.dart';
import 'package:app/features/library/library_screen.dart';
import 'package:app/features/library/playlist_detail_screen.dart';
import 'package:app/features/player/now_playing_screen.dart';
import 'package:app/features/search/search_screen.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/features/shell/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/library',
            builder: (_, __) => const LibraryScreen(),
            routes: [
              GoRoute(
                path: 'playlist',
                builder: (_, state) =>
                    PlaylistDetailScreen(playlist: state.extra as Map<String, dynamic>?),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ]),
      ],
    ),
    // Full-screen Now Playing pushed over the shell.
    GoRoute(
      path: '/now-playing',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, __) => const MaterialPage(fullscreenDialog: true, child: NowPlayingScreen()),
    ),
  ],
);
