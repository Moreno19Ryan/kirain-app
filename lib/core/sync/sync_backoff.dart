import 'dart:math' as math;

/// Exponential backoff with full jitter (the AWS Architecture Blog's
/// "Exponential Backoff And Jitter" pattern) — a uniformly random duration
/// between zero and the capped exponential ceiling, rather than sleeping the
/// full computed delay every time. Full jitter avoids every queued item that
/// failed at the same moment (e.g. a blip in connectivity) waking up and
/// retrying in lockstep.
class SyncBackoff {
  const SyncBackoff({this.base = const Duration(seconds: 2), this.max = const Duration(seconds: 60)});

  /// Delay for the first retry (attempt 0), before exponential growth.
  final Duration base;

  /// Ceiling that no computed delay — jittered or not — ever exceeds.
  final Duration max;

  /// [attempt] is zero-based (0 = the delay before the *second* try, i.e.
  /// after the first failure). [random] is injected so tests can assert on
  /// bounds deterministically without depending on wall-clock-seeded
  /// randomness.
  Duration delayForAttempt(int attempt, math.Random random) {
    final exponentialMs = base.inMilliseconds * math.pow(2, attempt);
    final cappedMs = math.min(exponentialMs.toDouble(), max.inMilliseconds.toDouble());
    final jitteredMs = random.nextDouble() * cappedMs;
    return Duration(milliseconds: jitteredMs.round());
  }
}
