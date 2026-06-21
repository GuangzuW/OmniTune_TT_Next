import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayService with TrayListener {
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onQuit;

  TrayService({
    required this.onPlayPause,
    required this.onNext,
    required this.onPrev,
    required this.onQuit,
  });

  Future<void> init() async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
      );
      List<MenuItem> items = [
        MenuItem(key: 'play_pause', label: 'Play/Pause'),
        MenuItem(key: 'next', label: 'Next'),
        MenuItem(key: 'prev', label: 'Previous'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Exit OmniTune'),
      ];
      await trayManager.setContextMenu(Menu(items: items));
      trayManager.addListener(this);
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'play_pause') {
      onPlayPause();
    } else if (menuItem.key == 'next') {
      onNext();
    } else if (menuItem.key == 'prev') {
      onPrev();
    } else if (menuItem.key == 'exit') {
      onQuit();
    }
  }
}
