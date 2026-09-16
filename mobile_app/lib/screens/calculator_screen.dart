import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'my_evidence_screen.dart';
import '../services/api_service.dart';
import '../stealth/stealth_controller.dart';
import '../stealth/triple_tap_detector.dart';
import '../stealth/recording_service.dart';
import 'login_screen.dart';

/// Stealth entry point for Digital Witness Vault.
///
/// This screen is a fully functional calculator and is the app's real
/// launcher UI (wired up in main.dart in a later phase). It intentionally
/// does NOT use AppTheme (the vault's navy/gold branding) so that it looks
/// like a plain, forgettable calculator app rather than something visually
/// tied to Digital Witness Vault.
///
/// Phase 3 added layout + core arithmetic. Phase 4 hardened the
/// calculator logic (error-state lockout, repeat-equals, contextual
/// percent, input-length capping, memory bar).
///
/// Phase 5 added triple-tap detection on the display, wired to
/// StealthController.toggleRecording() with a short haptic pulse to
/// confirm activation/deactivation.
///
/// Phase 6 wired that toggle to RecordingService, which holds the actual
/// camera+mic+upload logic (extracted from RecorderScreen so there's
/// exactly one implementation shared by both screens). First triple-tap
/// starts recording, the next stops it and uploads via the existing
/// /upload backend contract — all while this calculator screen stays
/// the only thing visible.
///
/// Phase 7 (this revision) adds the compliance/robustness layer around
/// that: a screen wakelock while recording (so idle screen-off doesn't
/// background the app mid-capture), and an app-lifecycle observer that
/// proactively stops and uploads if the app is genuinely backgrounded
/// while recording — since Android does not let any app keep a camera
/// session alive once truly backgrounded, silently losing the footage
/// would be worse than saving what was captured up to that point.
///
/// Known, unavoidable platform limitation (see Phase 2 discussion):
/// Android 12+ draws a small green camera/mic indicator dot in the
/// status bar whenever either is active, system-wide, for every app.
/// No app can suppress or opt out of this — it's an OS privacy feature,
/// not a permission this app requests. It's the only visual sign of
/// recording that exists outside this app's control.
///
/// Phase 8 (this revision) adds the hidden vault entry point: a 3-second
/// long-press on the display opens LoginScreen — the existing,
/// completely unmodified authentication screen. From there, Dashboard,
/// Upload, Evidence History, Evidence Detail, and Verify all work
/// exactly as they did before any of this stealth work started, since
/// none of those screens were touched. LoginScreen is pushed through
/// StealthController's shared navigatorKey rather than this screen's own
/// BuildContext, so Phase 9's panic exit can later pop back to the
/// calculator through the same key regardless of how deep the user has
/// navigated into the vault.
///
/// Phase 9 (this revision) adds panic exit: a long-press on the C button
/// stops any active stealth recording (fire-and-forget upload, doesn't
/// block the gesture), pops the vault's navigation stack back to this
/// calculator screen from any depth via the shared navigatorKey, and
/// resets the calculator's own display to a clean slate.
///
/// With this, all gestures from the original spec are implemented:
/// triple-tap to record, 3s long-press to open the vault, long-press-C
/// to panic-exit.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with WidgetsBindingObserver {
  // ---- Calculator engine state ----
  Future<void> _checkVaultCode() async {
  if (_display.length != 6 ||
      !RegExp(r'^\d{6}$').hasMatch(_display)) {
    return;
  }

  final code = _display;

  final result = await ApiService.unlockVault(code);

  if (!mounted) return;

  if (result['success'] == true) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyEvidenceScreen(),
      ),
    );

    _onAllClearPressed();
  }
}
  String _display = '0';
  static const String _vaultAccessCode = '2580';
  double? _storedValue;
  String? _pendingOperator;
  bool _shouldResetDisplay = false;
  bool _isError = false;

  // "Repeat equals" support: pressing = again re-applies the last
  // operator/operand pair, matching standard calculator behavior
  // (e.g. 5 + 3 = = = -> 8, 11, 14).
  String? _lastOperator;
  double? _lastOperand;

  // Simple memory register (M+ / M- / MR / MC).
  double _memory = 0;
  bool _hasMemory = false;

  // Hard cap on typed digits so the display can't overflow indefinitely.
  static const int _maxInputLength = 15;

  // ---- Stealth gesture state (Phase 5) ----
  late final TripleTapDetector _tripleTapDetector;

  // ---- Vault long-press state (Phase 8) ----
  // Custom timer-based long press rather than GestureDetector's built-in
  // onLongPress, because the built-in recognizer fires after Flutter's
  // default ~500ms — the spec calls for a full 3 seconds, which needs a
  // manually-driven timer instead.
  

  // Phase 10: prevents rapid re-triggers of the stealth gesture from
  // flapping StealthController.isRecording (and firing repeated haptic
  // pulses) faster than RecordingService can actually keep up. The
  // underlying start()/stopAndUpload() race is fixed at the service
  // layer (see RecordingService._serialized) — this flag is purely a UX
  // smoothing measure on top of that, not the correctness guarantee.
  bool _stealthActionInFlight = false;

  @override
  void initState() {
    super.initState();
    _tripleTapDetector = TripleTapDetector(
      onTripleTap: _handleStealthTripleTap,
    );
    WidgetsBinding.instance.addObserver(this);
  }

 @override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _tripleTapDetector.reset();
  super.dispose();
}

  /// Phase 7: Android gives no app the ability to keep recording once
  /// truly backgrounded (home button / app switcher) — the camera
  /// session will be torn down by the OS regardless of what this app
  /// wants. Rather than silently lose whatever was captured, proactively
  /// stop and upload as soon as a real backgrounding is detected, so the
  /// footage up to that point is saved. This intentionally reacts only
  /// to `paused` (true backgrounding), not `inactive` — `inactive` also
  /// fires for transient things like pulling down the notification
  /// shade or a brief system dialog, and cutting the recording every
  /// time that happens would lose evidence for no real reason.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        StealthController.instance.isRecording) {
      RecordingService.instance.stopAndUpload();
      StealthController.instance.setRecording(false);
    }
  }

  /// Fired when 3 taps land on the display within the detector's window.
  /// Toggles the shared StealthController and gives a short haptic pulse
  /// to confirm the action landed — no dialog, no visible UI change, per
  /// the spec.
  ///
  /// Phase 6: now actually drives RecordingService — first tap-triple
  /// starts camera+mic recording, the next one stops it and uploads via
  /// the existing /upload flow. Both happen with the calculator staying
  /// on screen the whole time; nothing here pushes a route or shows a
  /// SnackBar/dialog, since this path has no UI of its own by design.
  ///
  /// Phase 10: ignores re-triggers while a start/stop is already in
  /// flight — RecordingService now serializes the actual camera calls
  /// so overlapping calls can no longer corrupt state, but without this
  /// guard StealthController.isRecording (and the haptic pulse) would
  /// still flip back and forth faster than the camera can keep up with,
  /// which is confusing even though it's no longer unsafe.
  void _handleStealthTripleTap() async {
    if (_stealthActionInFlight) return;
    _stealthActionInFlight = true;

    final isNowRecording = StealthController.instance.toggleRecording();
    HapticFeedback.mediumImpact();

    try {
      if (isNowRecording) {
        final started = await RecordingService.instance.start();
        if (!started) {
          // Camera/mic permission missing, no camera hardware, or start
          // otherwise failed. Revert the toggle so StealthController
          // stays truthful about what's actually happening — silently,
          // per spec (no dialog telling the user why).
          StealthController.instance.toggleRecording();
        }
      } else {
        await RecordingService.instance.stopAndUpload();
      }
    } finally {
      _stealthActionInFlight = false;
    }
  }

  /// Starts the 3-second timer on pointer-down over the display. If the
  /// finger lifts before the timer fires, `_cancelVaultLongPress` cancels
  /// it (registered via onTapUp/onTapCancel below) and the touch is
  /// treated as a normal tap instead — feeding the triple-tap detector,
  /// same as always.
  



 

  /// Fires once the 3-second hold completes. Opens the existing,
  /// unmodified LoginScreen — no vibration, no visual change beforehand,
  /// per the spec (only the record-toggle gesture gets haptic
  /// confirmation). Marks `_vaultLongPressFired` so the onTap that the
  /// eventual finger-lift would otherwise also fire gets swallowed
  /// instead of registering as an extra tap on the triple-tap detector.
  void _openVault() {
  StealthController.instance.navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => const LoginScreen(),
    ),
  );
}

  /// Panic exit (Phase 9): long-press on the C button.
  ///
  /// Uses InkWell's built-in onLongPress (Flutter's default ~500ms), not
  /// the deliberately slow 3-second timer used for vault access — panic
  /// exit needs to be quick and easy to trigger under stress, the exact
  /// opposite design goal from vault access, which needs to be hard to
  /// trigger by accident.
  ///
  /// Order of operations matches the spec: stop any active recording,
  /// return the calculator to normal, hide every evidence screen.
  /// Stopping the recording is fire-and-forget — the upload happens over
  /// the network and this gesture must not block on it; the panic exit
  /// itself has to feel instantaneous regardless of upload speed.
  void _handlePanicExit() {
    if (StealthController.instance.isRecording) {
      RecordingService.instance.stopAndUpload();
      StealthController.instance.setRecording(false);
    }

    // Hide every evidence screen: pop the vault's navigation stack all
    // the way back to the calculator (route index 0), regardless of how
    // many screens deep the user had navigated (Dashboard -> History ->
    // Detail, etc.) — one call via the shared navigatorKey reaches all
    // of them at once.
    StealthController.instance.navigatorKey.currentState
        ?.popUntil((route) => route.isFirst);

    // Return the calculator itself to a clean slate too.
    _onAllClearPressed();
  }

  // ---- Colors: plain, generic calculator look ----
  static const Color _bg = Color(0xFF000000);
  static const Color _displayText = Colors.white;
  static const Color _numberBtn = Color(0xFF333333);
  static const Color _functionBtn = Color(0xFFA5A5A5);
  static const Color _operatorBtn = Color(0xFFFF9F0A);
  static const Color _numberText = Colors.white;
  static const Color _functionText = Colors.black;

  // ------------------------------------------------------------------
  // Button handling
  // ------------------------------------------------------------------

  void _onDigitPressed(String digit) {
  setState(() {
    if (_isError) {
      _clearErrorState();
    }

    if (_display == '0' || _shouldResetDisplay) {
      _display = digit;
      _shouldResetDisplay = false;
    } else if (_digitCount(_display) < _maxInputLength) {
      _display = _display + digit;
    }
  });

  // Check the secret vault code after exactly 6 digits.
  if (_display.length == 6 &&
      RegExp(r'^\d{6}$').hasMatch(_display)) {
    _checkVaultCode();
  }
}

  void _onDecimalPressed() {
    setState(() {
      if (_isError) {
        _clearErrorState();
        _display = '0.';
        return;
      }
      if (_shouldResetDisplay) {
        _display = '0.';
        _shouldResetDisplay = false;
        return;
      }
      if (!_display.contains('.')) {
        _display = '$_display.';
      }
    });
  }

  void _onAllClearPressed() {
    setState(() {
      _display = '0';
      _storedValue = null;
      _pendingOperator = null;
      _shouldResetDisplay = false;
      _lastOperator = null;
      _lastOperand = null;
      _isError = false;
    });
  }

  /// "C" behaves as a single-entry clear (clears current number only,
  /// keeps any pending operator/stored value intact).
  /// Long-press behavior on this button is reserved for the panic exit
  /// gesture added in a later phase — not implemented here.
  void _onClearPressed() {
    setState(() {
      _display = '0';
      _isError = false;
    });
  }

  void _onDeletePressed() {
    if (_isError) {
      // Backspace on an error clears it, same as AC would.
      _onAllClearPressed();
      return;
    }
    setState(() {
      if (_display.length <= 1 ||
          (_display.length == 2 && _display.startsWith('-'))) {
        _display = '0';
      } else {
        _display = _display.substring(0, _display.length - 1);
      }
    });
  }

  void _onSignTogglePressed() {
    if (_isError) return;
    setState(() {
      if (_display == '0') return;
      _display = _display.startsWith('-')
          ? _display.substring(1)
          : '-$_display';
    });
  }

  /// Contextual percent, matching common calculator conventions:
  /// - With no pending operator: 50 % -> 0.5
  /// - With a pending operator: 200 + 10 % -> treats 10% as 10% of the
  ///   stored value (20), so the follow-up "=" gives 220, not 200.02.
  void _onPercentPressed() {
    if (_isError) return;
    setState(() {
      final value = double.tryParse(_display) ?? 0;
      if (_pendingOperator != null && _storedValue != null) {
        _display = _formatResult(_storedValue! * (value / 100));
      } else {
        _display = _formatResult(value / 100);
      }
    });
  }

  void _onOperatorPressed(String operator) {
    if (_isError) return;
    final currentValue = double.tryParse(_display) ?? 0;

    setState(() {
      if (_pendingOperator != null && _shouldResetDisplay) {
        // User changed their mind about the operator without typing a
        // new number yet — just swap it, don't recompute.
        _pendingOperator = operator;
        return;
      }

      if (_pendingOperator != null) {
        // Chain operations: resolve the pending one first.
        final result = _applyOperator(
          _storedValue ?? 0,
          currentValue,
          _pendingOperator!,
        );
        if (result.isNaN || result.isInfinite) {
          _enterErrorState();
          return;
        }
        _display = _formatResult(result);
        _storedValue = result;
      } else {
        _storedValue = currentValue;
      }

      _pendingOperator = operator;
      _shouldResetDisplay = true;
    });
  }

  void _onEqualsPressed() {
  if (_display == _vaultAccessCode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );

    _onAllClearPressed();
    return;
  }

  if (_isError) return;

    final currentValue = double.tryParse(_display) ?? 0;

    setState(() {
      double a;
      double b;
      String op;

      if (_pendingOperator != null && _storedValue != null) {
        // Normal case: complete the pending operation, and remember it
        // in case "=" is pressed again.
        a = _storedValue!;
        b = currentValue;
        op = _pendingOperator!;
        _lastOperator = op;
        _lastOperand = b;
      } else if (_lastOperator != null && _lastOperand != null) {
        // Repeat-equals: no pending operator, so re-apply the last one
        // against the current display value (e.g. 5 + 3 = = -> 11).
        a = currentValue;
        b = _lastOperand!;
        op = _lastOperator!;
      } else {
        return;
      }

      final result = _applyOperator(a, b, op);
      if (result.isNaN || result.isInfinite) {
        _enterErrorState();
        return;
      }

      _display = _formatResult(result);
      _storedValue = null;
      _pendingOperator = null;
      _shouldResetDisplay = true;
    });
  }

  // ------------------------------------------------------------------
  // Memory register
  // ------------------------------------------------------------------

  void _onMemoryClear() {
    setState(() {
      _memory = 0;
      _hasMemory = false;
    });
  }

  void _onMemoryRecall() {
    if (!_hasMemory || _isError) return;
    setState(() {
      _display = _formatResult(_memory);
      _shouldResetDisplay = true;
    });
  }

  void _onMemoryAdd() {
    if (_isError) return;
    setState(() {
      _memory += double.tryParse(_display) ?? 0;
      _hasMemory = true;
      _shouldResetDisplay = true;
    });
  }

  void _onMemorySubtract() {
    if (_isError) return;
    setState(() {
      _memory -= double.tryParse(_display) ?? 0;
      _hasMemory = true;
      _shouldResetDisplay = true;
    });
  }

  // ------------------------------------------------------------------
  // Error state helpers
  // ------------------------------------------------------------------

  void _enterErrorState() {
    _display = 'Error';
    _storedValue = null;
    _pendingOperator = null;
    _lastOperator = null;
    _lastOperand = null;
    _shouldResetDisplay = true;
    _isError = true;
  }

  void _clearErrorState() {
    _isError = false;
    _display = '0';
  }

  int _digitCount(String s) => s.replaceAll(RegExp(r'[-.]'), '').length;

  double _applyOperator(double a, double b, String operator) {
    switch (operator) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '×':
        return a * b;
      case '÷':
        if (b == 0) return double.nan;
        return a / b;
      default:
        return b;
    }
  }

  String _formatResult(double value) {
    if (value.isNaN) return 'Error';
    if (value.isInfinite) return 'Error';
    // Normalize negative zero (e.g. 0 * -5 == -0.0 in IEEE 754) so the
    // display never shows a confusing "-0".
    if (value == 0) return '0';
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toStringAsFixed(0);
    }
    // Trim trailing zeros on decimals, cap precision to keep it readable.
    String s = value.toStringAsFixed(8);
    s = s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
    return s;
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text('Calculator'),
),
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDisplay(),
            _buildMemoryBar(),
            _buildButtonGrid(),
          ],
        ),
      ),
    );
  }

 Widget _buildDisplay() {
  return Expanded(
    flex: 2,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _tripleTapDetector.registerTap();
      },
      child: Container(
        alignment: Alignment.bottomRight,
        padding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 16,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomRight,
          child: Text(
            _display,
            style: const TextStyle(
              color: _displayText,
              fontSize: 72,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ),
    ),
  );
}
  /// Small MC / MR / M+ / M- row, styled like the memory row on any
  /// standard scientific calculator. Purely conventional — not part of
  /// the stealth gesture set, so it carries no special meaning here.
  Widget _buildMemoryBar() {
    final items = <_MemoryButtonSpec>[
      _MemoryButtonSpec('MC', _onMemoryClear, enabled: _hasMemory),
      _MemoryButtonSpec('MR', _onMemoryRecall, enabled: _hasMemory),
      _MemoryButtonSpec('M+', _onMemoryAdd, enabled: true),
      _MemoryButtonSpec('M-', _onMemorySubtract, enabled: true),
    ];

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: TextButton(
                onPressed: item.enabled ? item.onPressed : null,
                style: TextButton.styleFrom(
                  foregroundColor:
                      item.enabled ? _functionBtn : const Color(0xFF444444),
                ),
                child: Text(item.label, style: const TextStyle(fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButtonGrid() {
    final rows = <List<_CalcButtonSpec>>[
      [
        _CalcButtonSpec('AC', _functionBtn, _functionText, _onAllClearPressed),
        _CalcButtonSpec(
          'C',
          _functionBtn,
          _functionText,
          _onClearPressed,
          onLongPress: _handlePanicExit,
        ),
        _CalcButtonSpec('%', _functionBtn, _functionText, _onPercentPressed),
        _CalcButtonSpec('÷', _operatorBtn, _displayText, () => _onOperatorPressed('÷')),
      ],
      [
        _CalcButtonSpec('7', _numberBtn, _numberText, () => _onDigitPressed('7')),
        _CalcButtonSpec('8', _numberBtn, _numberText, () => _onDigitPressed('8')),
        _CalcButtonSpec('9', _numberBtn, _numberText, () => _onDigitPressed('9')),
        _CalcButtonSpec('×', _operatorBtn, _displayText, () => _onOperatorPressed('×')),
      ],
      [
        _CalcButtonSpec('4', _numberBtn, _numberText, () => _onDigitPressed('4')),
        _CalcButtonSpec('5', _numberBtn, _numberText, () => _onDigitPressed('5')),
        _CalcButtonSpec('6', _numberBtn, _numberText, () => _onDigitPressed('6')),
        _CalcButtonSpec('-', _operatorBtn, _displayText, () => _onOperatorPressed('-')),
      ],
      [
        _CalcButtonSpec('1', _numberBtn, _numberText, () => _onDigitPressed('1')),
        _CalcButtonSpec('2', _numberBtn, _numberText, () => _onDigitPressed('2')),
        _CalcButtonSpec('3', _numberBtn, _numberText, () => _onDigitPressed('3')),
        _CalcButtonSpec('+', _operatorBtn, _displayText, () => _onOperatorPressed('+')),
      ],
    ];

    return Expanded(
      flex: 5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            for (final row in rows)
              Expanded(
                child: Row(
                  children: [
                    for (final spec in row)
                      Expanded(child: _buildButton(spec)),
                  ],
                ),
              ),
            // Bottom row: sign toggle, 0, decimal, delete, equals
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildButton(_CalcButtonSpec(
                        '+/-', _functionBtn, _functionText, _onSignTogglePressed)),
                  ),
                  Expanded(
                    child: _buildButton(_CalcButtonSpec(
                        '0', _numberBtn, _numberText, () => _onDigitPressed('0'))),
                  ),
                  Expanded(
                    child: _buildButton(_CalcButtonSpec(
                        '.', _numberBtn, _numberText, _onDecimalPressed)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildButton(_CalcButtonSpec(
                        '⌫', _functionBtn, _functionText, _onDeletePressed)),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildButton(_CalcButtonSpec(
                        '=', _operatorBtn, _displayText, _onEqualsPressed)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(_CalcButtonSpec spec) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: spec.bgColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: spec.onPressed,
          onLongPress: spec.onLongPress,
          child: Center(
            child: Text(
              spec.label,
              style: TextStyle(
                color: spec.textColor,
                fontSize: 26,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalcButtonSpec {
  final String label;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  _CalcButtonSpec(
    this.label,
    this.bgColor,
    this.textColor,
    this.onPressed, {
    this.onLongPress,
  });
}

class _MemoryButtonSpec {
  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  _MemoryButtonSpec(this.label, this.onPressed, {required this.enabled});
}
