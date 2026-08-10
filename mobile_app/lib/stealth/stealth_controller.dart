import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show GlobalKey, NavigatorState;

/// Single source of truth for the app's stealth state.
///
/// A plain singleton rather than something scoped to a widget's lifecycle,
/// because the recording toggle needs to survive independent of whatever
/// widget rebuilds happen on the calculator screen, and (from Phase 6
/// onward) needs to be reachable from RecordingService as well.
///
/// Tracks whether stealth recording is armed/disarmed and notifies
/// listeners on change. RecordingService (Phase 6) is driven by the
/// calculator screen's gesture handlers rather than by this controller
/// directly — this class is the shared state both sides read/write so
/// they stay in sync (e.g. Phase 7's app-lifecycle handler force-stops
/// recording and needs to correct this flag from outside the normal
/// toggle path).
///
/// Phase 8 adds `navigatorKey`: a single, app-wide
/// GlobalKey<NavigatorState> assigned to MaterialApp in main.dart. The
/// long-press-to-open-vault gesture pushes LoginScreen through this key
/// rather than a widget's own BuildContext, so the same key can be used
/// by Phase 9's panic exit to pop back to the calculator from anywhere
/// in the vault's navigation stack (Dashboard -> History -> Detail,
/// etc.) in one call, regardless of how deep the user has navigated.
class StealthController extends ChangeNotifier {
  StealthController._internal();
  static final StealthController instance = StealthController._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Flips the recording flag. Called by the triple-tap gesture on the
  /// calculator display. Returns the new state so the caller (currently:
  /// just haptic feedback) knows which direction the toggle went.
  bool toggleRecording() {
    _isRecording = !_isRecording;
    notifyListeners();
    return _isRecording;
  }

  /// Sets the recording flag directly, for code paths that need to
  /// correct the state rather than flip it — e.g. Phase 7's app-
  /// lifecycle handler, which force-stops recording when the app is
  /// truly backgrounded and needs to mark it off without assuming
  /// which direction a toggle would go.
  void setRecording(bool value) {
    if (_isRecording == value) return;
    _isRecording = value;
    notifyListeners();
  }
}
