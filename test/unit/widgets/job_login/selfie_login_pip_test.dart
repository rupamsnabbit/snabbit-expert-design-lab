import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/widgets/job_login/selfie_login.dart';

void main() {
  group('classifyPipTransition', () {
    // A typical full-screen phone window in portrait. Note the shortest
    // side (411) is itself below the 500dp threshold — which is exactly
    // why the classifier keys off the LONGEST side (891), not the shortest.
    const fullScreen = Size(411.0, 891.0); // longestSide 891 → not PiP
    // A typical PiP window — small in both dimensions.
    const pipWindow = Size(220.0, 124.0); // longestSide 220 → PiP

    test('returns none on the first callback (no previous size)', () {
      expect(
        classifyPipTransition(null, fullScreen),
        PipTransition.none,
      );
    });

    test('detects PiP entry: full screen -> small window', () {
      expect(
        classifyPipTransition(fullScreen, pipWindow),
        PipTransition.entered,
      );
    });

    test('detects PiP exit: small window -> full screen', () {
      expect(
        classifyPipTransition(pipWindow, fullScreen),
        PipTransition.exited,
      );
    });

    test('portrait phone is NOT mistaken for PiP despite narrow width', () {
      // Regression guard: shortestSide of a portrait phone (411) is below
      // the threshold; the classifier must not treat that as PiP.
      expect(
        classifyPipTransition(fullScreen, const Size(411.0, 891.0)),
        PipTransition.none,
      );
    });

    test('returns none when staying full screen (e.g. rotation)', () {
      // Portrait -> landscape, both above threshold on longest side.
      expect(
        classifyPipTransition(fullScreen, const Size(891.0, 411.0)),
        PipTransition.none,
      );
    });

    test('returns none when staying in PiP (minor PiP resize)', () {
      expect(
        classifyPipTransition(pipWindow, const Size(180.0, 320.0)),
        PipTransition.none,
      );
    });

    group('threshold boundary (default 500dp on longest side)', () {
      test('a longest side exactly at the threshold counts as NOT PiP', () {
        // longestSide == threshold is not "< threshold", so not PiP.
        const atThreshold = Size(300.0, 500.0); // longestSide 500
        expect(
          classifyPipTransition(pipWindow, atThreshold),
          PipTransition.exited,
        );
        expect(
          classifyPipTransition(atThreshold, pipWindow),
          PipTransition.entered,
        );
      });

      test('just below the threshold counts as PiP', () {
        const justBelow = Size(300.0, 499.0); // longestSide 499 → PiP
        expect(
          classifyPipTransition(fullScreen, justBelow),
          PipTransition.entered,
        );
      });

      test('respects a custom threshold override', () {
        // With a 300dp threshold, an 891-long window is "not PiP" and a
        // 290-long window is "PiP".
        expect(
          classifyPipTransition(
            fullScreen,
            const Size(250.0, 290.0),
            threshold: 300.0,
          ),
          PipTransition.entered,
        );
      });
    });

    test('a tall narrow strip is NOT PiP (longest side stays large)', () {
      // A 140x600 sliver (e.g. split-screen) keeps a large longest side,
      // so we deliberately do not tear the camera down for it.
      expect(
        classifyPipTransition(fullScreen, const Size(140.0, 600.0)),
        PipTransition.none,
      );
    });
  });
}
