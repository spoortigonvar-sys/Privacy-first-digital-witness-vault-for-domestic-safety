import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../models/evidence_model.dart';
import '../utils/app_theme.dart';

/// Mobile equivalent of the website's Emergency Recorder
/// (frontend/recorder.html + frontend/js/recorder.js).
///
/// The website used getUserMedia() + MediaRecorder() in the browser to
/// capture camera+mic, then uploaded the resulting Blob to POST /upload.
/// This screen does the same thing using the device camera: start camera
/// preview, record video+audio, stop, then upload the resulting file to
/// the same /upload endpoint — preserving the exact same backend contract.
class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

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
    // Camera + microphone permission (equivalent to the browser's
    // getUserMedia({video:true, audio:true}) permission prompt).
    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (!camStatus.isGranted || !micStatus.isGranted) {
      setState(() => _statusText = '❌ Camera Permission Denied');
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _statusText = '❌ No camera found on this device');
        return;
      }

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

      if (!mounted) return;

      setState(() {
        _controller = controller;
        _cameraReady = true;
        _statusText = '✅ Camera Ready';
      });
    } catch (e) {
      setState(() => _statusText = '❌ Camera Permission Denied');
    }
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
    if (_controller == null || !_cameraReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera not ready.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    try {
      await _controller!.startVideoRecording();
      _startTimer();
      setState(() {
        _isRecording = true;
        _statusText = '🔴 Recording...';
        _lastResult = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('MediaRecorder Error: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) return;

    _stopTimer();
    setState(() => _isRecording = false);

    try {
      final XFile videoFile = await _controller!.stopVideoRecording();
      await _uploadRecording(File(videoFile.path));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload Error: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
      setState(() => _statusText = '❌ Upload Failed');
    }
  }

  Future<void> _uploadRecording(File file) async {
    setState(() {
      _isUploading = true;
      _statusText = '⬆ Uploading...';
    });

    try {
      final result = await ApiService.uploadEvidence(file);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _lastResult = result['data'] as EvidenceModel;
          _statusText = '✅ Upload Successful';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload Successful'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        setState(() => _statusText = '❌ Upload Failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Upload Failed. Status error.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusText = '❌ Upload Failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload Error: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
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
                child: _cameraReady && _controller != null
                    ? CameraPreview(_controller!)
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
