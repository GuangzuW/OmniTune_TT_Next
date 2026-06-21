// Smoke tests for OmniTune. The full app pulls in native FFI, audio_service and
// desktop plugins on init (not available in the headless harness), so these
// tests cover plugin-free surface area: theme + player constants/logic.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/state/player_controller.dart';

void main() {
  test('Dark theme uses the coral brand accent as primary', () {
    final theme = AppTheme.dark;
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppColors.coral);
  });

  test('Every EQ preset has exactly 10 bands', () {
    expect(kEqFreqs.length, 10);
    for (final entry in kEqPresets.entries) {
      expect(entry.value.length, 10, reason: '${entry.key} must have 10 bands');
    }
  });

  test('RepeatMode has off/all/one', () {
    expect(RepeatMode.values, [RepeatMode.off, RepeatMode.all, RepeatMode.one]);
  });

  test('PlayerState.current is null on an empty queue', () {
    const s = PlayerState();
    expect(s.current, isNull);
    expect(s.hasTrack, isFalse);
  });
}
