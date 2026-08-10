import 'package:flutter/foundation.dart';

/// Detects a triple tap landing within [window] and fires [onTripleTap].
///
/// This is plain Dart, not a widget — it just tracks tap timestamps in a
/// rolling window so it can be fed taps from wherever the gesture should
/// be recognized (currently: the calculator display, wired up in
/// CalculatorScreen). Keeping it separate from any widget makes it easy
/// to unit test in isolation and reuse if another tap target is added
/// later.
class TripleTapDetector {
  TripleTapDetector({
    this.window = const Duration(seconds: 2),
    required this.onTripleTap,
  });

  /// How close together the 3 taps must land. Matches the spec: "triple
  /// taps the calculator display within approximately 2 seconds".
  final Duration window;

  final VoidCallback onTripleTap;

  final List<DateTime> _tapTimes = [];

  /// Call this once per tap on the watched target.
  void registerTap() {
    final now = DateTime.now();
    _tapTimes.add(now);

    // Drop any taps that have already fallen outside the rolling window,
    // so e.g. tap...tap (1.5s gap)...tap (1.5s gap) never triggers -
    // only 3 taps that are ALL mutually within the window count.
    _tapTimes.removeWhere((t) => now.difference(t) > window);

    if (_tapTimes.length >= 3) {
      _tapTimes.clear();
      onTripleTap();
    }
  }

  /// Clears any in-progress tap sequence (e.g. call on screen dispose).
  void reset() => _tapTimes.clear();
}
