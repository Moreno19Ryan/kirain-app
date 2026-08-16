import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/core/sync/sync_backoff.dart';

/// A [math.Random] stand-in that always returns a fixed `nextDouble()`, so
/// backoff delays are exactly predictable instead of merely bounded.
class _FixedRandom implements math.Random {
  const _FixedRandom(this._value);

  final double _value;

  @override
  double nextDouble() => _value;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;
}

void main() {
  group('SyncBackoff', () {
    const backoff = SyncBackoff(base: Duration(seconds: 2), max: Duration(seconds: 60));

    test('exponential growth: the delay ceiling doubles per attempt before capping', () {
      // With jitter fixed at 1.0 (the top of the [0, 1) range), the
      // returned delay equals the ceiling itself, making the exponential
      // curve directly observable: 2s, 4s, 8s, 16s, 32s, then capped at 60s.
      const random = _FixedRandom(1.0);

      expect(backoff.delayForAttempt(0, random), const Duration(seconds: 2));
      expect(backoff.delayForAttempt(1, random), const Duration(seconds: 4));
      expect(backoff.delayForAttempt(2, random), const Duration(seconds: 8));
      expect(backoff.delayForAttempt(3, random), const Duration(seconds: 16));
      expect(backoff.delayForAttempt(4, random), const Duration(seconds: 32));
      expect(backoff.delayForAttempt(5, random), const Duration(seconds: 60));
      expect(backoff.delayForAttempt(10, random), const Duration(seconds: 60));
    });

    test('full jitter: a zero-valued random gives a zero delay at any attempt', () {
      const random = _FixedRandom(0);

      expect(backoff.delayForAttempt(0, random), Duration.zero);
      expect(backoff.delayForAttempt(4, random), Duration.zero);
    });

    test('jitter stays within [0, ceiling] across many samples and attempts', () {
      final random = math.Random(1234); // seeded for a reproducible run

      for (var attempt = 0; attempt < 8; attempt++) {
        final ceilingMs = math.min(2000 * math.pow(2, attempt), 60000).toDouble();
        for (var sample = 0; sample < 200; sample++) {
          final delay = backoff.delayForAttempt(attempt, random);
          expect(delay.inMilliseconds, greaterThanOrEqualTo(0));
          expect(delay.inMilliseconds, lessThanOrEqualTo(ceilingMs.round()));
        }
      }
    });

    test('never exceeds the configured maximum, no matter how large the attempt number', () {
      const random = _FixedRandom(1.0);

      expect(backoff.delayForAttempt(50, random), const Duration(seconds: 60));
    });
  });
}
