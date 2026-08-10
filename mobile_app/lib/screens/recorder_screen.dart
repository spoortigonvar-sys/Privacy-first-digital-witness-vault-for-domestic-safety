import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/evidence_model.dart';
import '../utils/app_theme.dart';
import '../stealth/recording_service.dart';

/// Mobile equivalent of the website's Emergency Recorder
/// (frontend/recorder.html + frontend/js/recorder.js).
///
/// The website used getUserMedia() + MediaRecorder() in the browser to
/// capture camera+mic, then uploaded the resulting Blob to POST /upload.
/// This screen does the same thing using the device camera: start camera
/// preview, record video+audio, stop, then upload the resulting file to
/// the same /upload endpoint — preserving the exact same backend contract.
///
/// Phase 6: the camera/record/upload logic that used to live directly in
/// this State object has been extracted into RecordingService, which is
/// now shared with the stealth triple-tap trigger on the calculator
/// screen. This screen's behavior is unchanged from the user's point of
/// view — it just delegates instead of owning the CameraController
/// itself, so there is exactly one implementation of "record and upload"
/// in the app, not two.
class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  final RecordingService _service = RecordingService.instance;

  bool _cameraReady = false;
  String _statusText = 'Camera not started';

  bool _isRecording = false;
  bool _isUploading = false;

  int _seconds = 0;
  Timer? _timer;

  EvidenceModel? _lastResult;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    final ok = await _service.ensureInitialized();

    if (!mounted) return;

    if (!ok) {
      // ensureInitialized() covers both "permission denied" and "no
      // camera available" — RecordingService doesn't currently surface
      // which one, so this message covers both, matching the original
      // screen's behavior of a single denial message either way.
      setState(() => _statusText = '❌ Camera Permission Denied');
      return;
    }

    setState(() {
      _cameraReady = true;
      _statusText = '✅ Camera Ready';
    });
  }

  void _startTimer() {
    _seconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String get _formattedTime {
    final min = (_seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (_seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Future<void> _startRecording() async {
    if (!_cameraReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera not ready.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final started = await _service.start();

    if (!mounted) return;

    if (started) {
      _startTimer();
      setState(() {
        _isRecording = true;
        _statusText = '🔴 Recording...';
        _lastResult = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MediaRecorder Error: could not start recording'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (!_service.isRecording) return;

    _stopTimer();
    setState(() {
      _isRecording = false;
      _isUploading = true;
      _statusText = '⬆ Uploading...';
    });

    final evidence = await _service.stopAndUpload();

    if (!mounted) return;

    if (evidence != null) {
      setState(() {
        _lastResult = evidence;
        _statusText = '✅ Upload Successful';
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload Successful'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      setState(() {
        _statusText = '❌ Upload Failed';
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload Failed. Please try again.'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Deliberately NOT calling _service.release() here. RecordingService
    // is a shared singleton also used by the stealth triple-tap trigger
    // on the calculator screen (Phase 6+), which can outlive this
    // screen's lifecycle. A per-screen widget tearing down a resource it
    // doesn't exclusively own would risk killing an in-progress stealth
    // recording started elsewhere. The camera is released explicitly by
    // whichever flow is actually done with it (currently: nothing does
    // this automatically, matching the original screen's simple
    // lifecycle — revisit if profiling shows the camera being held open
    // longer than desired).
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Recorder')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Record video and audio securely during emergencies.',
              style: TextStyle(color: AppTheme.textLight),
            ),
            const SizedBox(height: 16),

            // Camera preview box
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accent, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _cameraReady && _service.controller != null
                    ? CameraPreview(_service.controller!)
                    : const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.accent,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: Text(
                'Recording Time: $_formattedTime',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (!_cameraReady || _isRecording || _isUploading)
                        ? null
                        : _startRecording,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Recording'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                    ),
                    onPressed: (!_isRecording || _isUploading)
                        ? null
                        : _stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Recording'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  if (_isUploading)
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Backend Response',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _row('Evidence ID', _lastResult!.evidenceId),
                      _row('Filename', _lastResult!.filename),
                      _row('SHA-256', _lastResult!.sha256, mono: true),
                      _row('Upload Time', _lastResult!.uploadTime),
                      _row('Status', _lastResult!.status),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textLight,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: mono ? 12 : 14,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}
