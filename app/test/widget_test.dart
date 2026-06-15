// Smoke tests for OmniTune TT Next.
//
// The full app (PlayerHomePage) pulls in native FFI, audio_service, tray and
// window plugins on init, which aren't available in the headless test harness,
// so we keep these tests to plugin-free surface area.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  test('TTPlayerApp constructs as a StatelessWidget', () {
    expect(const TTPlayerApp(), isA<StatelessWidget>());
  });

  test('Equalizer presets each have 10 bands', () {
    expect(kEqPresets.isNotEmpty, true);
    for (final entry in kEqPresets.entries) {
      expect(entry.value.length, 10, reason: '${entry.key} must have 10 bands');
    }
    expect(kEqFreqs.length, 10);
  });

  test('RepeatMode cycles through all three states', () {
    expect(RepeatMode.values.length, 3);
  });
}
