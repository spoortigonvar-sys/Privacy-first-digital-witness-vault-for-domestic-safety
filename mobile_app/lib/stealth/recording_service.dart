
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/evidence_model.dart';
import '../services/api_service.dart';

class RecordingService {
  RecordingService._internal();

  static final RecordingService instance =
      RecordingService._internal();

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  Future<void> _operationLock = Future.value();

  Future<T> _serialized<T>(
    Future<T> Function() action,
  ) {
    final result = _operationLock.then((_) => action());

    _operationLock = result.then(
      (_) => null,
      onError: (_) => null,
    );

    return result;
  }

  bool get isInitialized => _isInitialized;

  bool get isRecording =>
      _controller?.value.isRecordingVideo ?? false;

  CameraController? get controller => _controller;

  Future<bool> ensureInitialized() async {
    if (_isInitialized && _controller != null) {
      return true;
    }

    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (!camStatus.isGranted || !micStatus.isGranted) {
      print('Camera or microphone permission denied.');
      return false;
    }

    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        print('No cameras found.');
        return false;
      }

      final backCamera = _cameras.firstWhere(
        (camera) =>
            camera.lensDirection == CameraLensDirection.back,
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

      print('Camera initialized successfully.');
      return true;
    } catch (e) {
      print('Camera initialization failed: $e');
      _isInitialized = false;
      _controller = null;
      return false;
    }
  }

  Future<bool> start() => _serialized(() async {
        if (!_isInitialized || _controller == null) {
          final initialized = await ensureInitialized();

          if (!initialized) {
            return false;
          }
        }

        if (_controller!.value.isRecordingVideo) {
          return true;
        }

        try {
          await _controller!.startVideoRecording();
          await WakelockPlus.enable();

          print('Video recording started.');
          return true;
        } catch (e) {
          print('Failed to start recording: $e');
          return false;
        }
      });

  Future<EvidenceModel?> stopAndUpload() =>
      _serialized(() async {
        if (_controller == null ||
            !_controller!.value.isRecordingVideo) {
          print('No active recording found.');
          await WakelockPlus.disable();
          return null;
        }

        try {
          // Stop recording and obtain the saved video.
          final XFile videoFile =
              await _controller!.stopVideoRecording();

          final File savedVideo = File(videoFile.path);

          print('VIDEO PATH: ${videoFile.path}');

          // Verify that the file exists.
          final bool exists = await savedVideo.exists();
          print('VIDEO EXISTS: $exists');

          if (!exists) {
            print('VIDEO FILE WAS NOT SAVED.');
            return null;
          }

          final int size = await savedVideo.length();
          print('VIDEO SIZE: $size bytes');

          if (size == 0) {
            print('VIDEO FILE IS EMPTY.');
            return null;
          }

          // Upload the recording to the FastAPI backend.
          print('Starting evidence upload...');

          final result =
              await ApiService.uploadEvidence(savedVideo);

          if (result['success'] == true) {
            print('Evidence uploaded successfully.');

            final evidence = result['data'];

            if (evidence is EvidenceModel) {
              return evidence;
            }

            print(
              'Upload succeeded, but evidence response '
              'has an unexpected format.',
            );
            return null;
          }

          print(
            'Evidence upload failed: '
            '${result['message'] ?? 'Unknown error'}',
          );

          return null;
        } catch (e, stackTrace) {
          print('Failed to stop or upload recording: $e');
          print(stackTrace);
          return null;
        } finally {
          await WakelockPlus.disable();
        }
      });

  Future<void> release() async {
    try {
      await _controller?.dispose();
    } catch (e) {
      print('Error releasing camera: $e');
    }

    _controller = null;
    _isInitialized = false;

    await WakelockPlus.disable();
  }
}
