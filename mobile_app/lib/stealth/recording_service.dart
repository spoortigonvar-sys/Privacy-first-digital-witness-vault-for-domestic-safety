import 'dart:io';

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/evidence_model.dart';
import '../services/api_service.dart';

/// Camera + record + upload logic, extracted from RecorderScreen so the
/// exact same behavior can be driven from two places:
///   1. RecorderScreen — the authenticated, visible "Emergency Recorder"
///      screen inside the vault (unchanged UI, now delegates here).
///   2. The stealth triple-tap gesture on the calculator screen, which
///      has no UI of its own for recording (per spec: no recorder page,
///      no visible transition).
///
/// This is a plain singleton (not a widget, not tied to any screen's
/// lifecycle) so recording state survives regardless of which screen is
/// currently mounted, and so both call sites share one CameraController
/// instead of fighting over the hardware.
///
/// Reuses the existing /upload backend contract exactly as RecorderScreen
/// always has — same endpoint, same multipart request, same EvidenceModel
/// response parsing.
class RecordingService {
  RecordingService._internal();
  static final RecordingService instance = RecordingService._internal();

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  // Phase 10 fix: serializes start()/stopAndUpload() so they can never
  // run concurrently, no matter which caller triggers them (calculator
  // triple-tap, panic exit, or RecorderScreen). Without this, a rapid
  // re-trigger during start()'s camera-init await (first use only —
  // permission prompt + hardware init) could race with a stop() call
  // landing before start() finishes, and whichever actually completed
  // last would silently decide the real camera state — potentially
  // leaving the camera recording even though the most recent gesture
  // said "stop". Chaining onto `_operationLock` at call time (not await
  // time) fixes the ordering without forcing callers to await it, so
  // fire-and-forget call sites (panic exit) still don't block on it.
  Future<void> _operationLock = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _operationLock.then((_) => action());
    _operationLock = result.then((_) => null, onError: (_) => null);
    return result;
  }

  bool get isInitialized => _isInitialized;
  bool get isRecording => _controller?.value.isRecordingVideo ?? false;

  /// Exposed so a visible screen (RecorderScreen) can show a live
  /// CameraPreview. The stealth path never reads this.
  CameraController? get controller => _controller;

  /// Requests camera + microphone permission and initializes the
  /// controller. Safe to call repeatedly — it's a no-op once already
  /// initialized, so both call sites can call this unconditionally
  /// before starting a recording.
  Future<bool> ensureInitialized() async {
    if (_isInitialized && _controller != null) return true;

    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (!camStatus.isGranted || !micStatus.isGranted) {
      return false;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return false;

      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await controller.initialize();

      _controller = controller;
      _isInitialized = true;
      return true;
    } catch (_) {
      _isInitialized = false;
      _controller = null;
      return false;
    }
  }

  /// Starts video recording. Initializes the camera first if needed.
  /// Returns false if permissions are missing, no camera is available,
  /// or recording otherwise fails to start.
  ///
  /// Phase 7: also enables a screen wakelock while recording, so a
  /// normal idle screen-off doesn't background the app (and kill the
  /// camera session) mid-capture. This does NOT keep the app alive if
  /// the user deliberately backgrounds it (home button / app switch) —
  /// see StealthController's lifecycle handling for that case, which
  /// Android does not allow any app to override.
  Future<bool> start() => _serialized(() async {
        if (!_isInitialized || _controller == null) {
          final ok = await ensureInitialized();
          if (!ok) return false;
        }

        if (_controller!.value.isRecordingVideo) return true;

        try {
          await _controller!.startVideoRecording();
          await WakelockPlus.enable();
          return true;
        } catch (_) {
          return false;
        }
      });

  /// Stops recording, then hashes/encrypts/stores it via the existing
  /// backend by uploading to /upload (all done server-side, unchanged).
  /// Returns the parsed EvidenceModel on success, or null on failure —
  /// callers with no UI (the stealth path) can safely ignore a null
  /// result; callers with UI (RecorderScreen) use it to show status.
  Future<EvidenceModel?> stopAndUpload() => _serialized(() async {
        if (_controller == null || !_controller!.value.isRecordingVideo) {
          await WakelockPlus.disable();
          return null;
        }

        try {
          final XFile videoFile = await _controller!.stopVideoRecording();
          final result =
              await ApiService.uploadEvidence(File(videoFile.path));

          if (result['success'] == true) {
            return result['data'] as EvidenceModel;
          }
          return null;
        } catch (_) {
          return null;
        } finally {
          await WakelockPlus.disable();
        }
      });

  /// Releases the camera hardware. Deliberately NOT called automatically
  /// from any screen's dispose() — see the comment in RecorderScreen for
  /// why a per-screen widget shouldn't tear down this shared singleton.
  Future<void> release() async {
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    await WakelockPlus.disable();
  }
}
