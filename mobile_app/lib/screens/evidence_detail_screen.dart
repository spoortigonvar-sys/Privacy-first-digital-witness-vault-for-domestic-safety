import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../models/evidence_model.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class EvidenceDetailScreen extends StatefulWidget {
  final EvidenceModel evidence;

  const EvidenceDetailScreen({
    super.key,
    required this.evidence,
  });

  @override
  State<EvidenceDetailScreen> createState() =>
      _EvidenceDetailScreenState();
}

class _EvidenceDetailScreenState
    extends State<EvidenceDetailScreen> {

  VideoPlayerController? _controller;

  File? _tempVideoFile;

  bool _loadingVideo = true;
  bool _videoError = false;

  String _videoErrorMessage = '';

  bool _verifying = false;

  Map<String, dynamic>? _verifyResult;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  // =========================================================
  // LOAD VIDEO FROM FASTAPI
  // =========================================================

  Future<void> _loadVideo() async {

    if (mounted) {
      setState(() {
        _loadingVideo = true;
        _videoError = false;
        _videoErrorMessage = '';
      });
    }

    try {

      // -----------------------------------------------------
      // GET VIDEO URL
      // -----------------------------------------------------

      final videoUrl =
          await ApiService.getEvidenceVideoUrl(
        widget.evidence.evidenceId,
      );

      if (videoUrl == null) {

        throw Exception(
          'Unable to create video URL'
        );
      }

      debugPrint(
        'VIDEO URL: $videoUrl'
      );

      // -----------------------------------------------------
      // DOWNLOAD VIDEO FROM FASTAPI
      // -----------------------------------------------------

      debugPrint(
        'Downloading video from FastAPI...'
      );

      final response = await http.get(
        Uri.parse(videoUrl),
      );

      debugPrint(
        'VIDEO HTTP STATUS: ${response.statusCode}'
      );

      debugPrint(
        'VIDEO SIZE: ${response.bodyBytes.length} bytes'
      );

      if (response.statusCode != 200) {

        throw Exception(
          'Video request failed: '
          '${response.statusCode}'
        );
      }

      if (response.bodyBytes.isEmpty) {

        throw Exception(
          'Video response is empty'
        );
      }

      // -----------------------------------------------------
      // CREATE TEMPORARY FILE
      // -----------------------------------------------------

      final tempDirectory =
          await Directory.systemTemp.createTemp(
        'digital_witness_video_',
      );

      final tempFile = File(
        '${tempDirectory.path}/${widget.evidence.filename}',
      );

      await tempFile.writeAsBytes(
        response.bodyBytes,
        flush: true,
      );

      debugPrint(
        'Temporary video saved at: ${tempFile.path}'
      );

      // -----------------------------------------------------
      // CREATE VIDEO PLAYER FROM LOCAL TEMP FILE
      // -----------------------------------------------------

      final controller =
          VideoPlayerController.file(
        tempFile,
      );

      await controller.initialize();

      if (!mounted) {

        await controller.dispose();

        return;
      }

      setState(() {

        _tempVideoFile = tempFile;

        _controller = controller;

        _loadingVideo = false;

        _videoError = false;

      });

      debugPrint(
        'VIDEO INITIALIZED SUCCESSFULLY'
      );

    } catch (e, stackTrace) {

      debugPrint(
        'VIDEO LOAD ERROR: $e'
      );

      debugPrint(
        stackTrace.toString()
      );

      if (mounted) {

        setState(() {

          _loadingVideo = false;

          _videoError = true;

          _videoErrorMessage =
              e.toString();

        });
      }
    }
  }

  // =========================================================
  // VERIFY EVIDENCE
  // =========================================================

  Future<void> _verifyNow() async {

    setState(() {
      _verifying = true;
      _verifyResult = null;
    });

    final result =
        await ApiService.verifyEvidence(
      widget.evidence.evidenceId,
    );

    if (!mounted) return;

    setState(() {
      _verifying = false;
      _verifyResult = result;
    });
  }

  // =========================================================
  // CLEAN TEMP FILE
  // =========================================================

  Future<void> _deleteTempVideo() async {

    try {

      if (_tempVideoFile != null &&
          await _tempVideoFile!.exists()) {

        await _tempVideoFile!.delete();

        debugPrint(
          'Temporary video deleted'
        );
      }

      final parent =
          _tempVideoFile?.parent;

      if (parent != null &&
          await parent.exists()) {

        await parent.delete();
      }

    } catch (e) {

      debugPrint(
        'Temporary file cleanup failed: $e'
      );
    }
  }

  @override
  void dispose() {

    _controller?.dispose();

    _deleteTempVideo();

    super.dispose();
  }

  // =========================================================
  // VIDEO PLAYER
  // =========================================================

  Widget _buildVideoPlayer() {

    if (_loadingVideo) {

      return Container(
        height: 230,
        decoration: BoxDecoration(
          color: AppTheme.primaryDark,
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              CircularProgressIndicator(),

              SizedBox(height: 12),

              Text(
                'Loading secure evidence...',
                style: TextStyle(
                  color: AppTheme.textLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_videoError ||
        _controller == null) {

      return Container(
        height: 230,
        decoration: BoxDecoration(
          color: AppTheme.primaryDark,
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(16),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [

                const Icon(
                  Icons.video_library_outlined,
                  size: 50,
                  color: AppTheme.textLight,
                ),

                const SizedBox(height: 10),

                const Text(
                  'Unable to load video',
                  style: TextStyle(
                    color: AppTheme.textLight,
                  ),
                ),

                const SizedBox(height: 8),

                if (_videoErrorMessage.isNotEmpty)

                  Text(
                    _videoErrorMessage,
                    textAlign:
                        TextAlign.center,
                    maxLines: 3,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      color:
                          AppTheme.textLight,
                      fontSize: 11,
                    ),
                  ),

                const SizedBox(height: 12),

                TextButton.icon(
                  onPressed: _loadVideo,
                  icon: const Icon(
                    Icons.refresh,
                  ),
                  label: const Text(
                    'Retry',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller =
        _controller!;

    return Column(
      children: [

        ClipRRect(
          borderRadius:
              BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio:
                controller.value.aspectRatio,
            child:
                VideoPlayer(controller),
          ),
        ),

        const SizedBox(height: 8),

        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [

            IconButton(
              iconSize: 36,
              color: AppTheme.accent,
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_circle
                    : Icons.play_circle,
              ),
              onPressed: () {

                setState(() {

                  if (controller.value.isPlaying) {

                    controller.pause();

                  } else {

                    controller.play();

                  }

                });
              },
            ),

            IconButton(
              iconSize: 30,
              color: AppTheme.accent,
              icon: const Icon(
                Icons.replay,
              ),
              onPressed: () {

                controller.seekTo(
                  Duration.zero,
                );

                controller.play();

                setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================
  // DETAIL ROW
  // =========================================================

  Widget _detailRow(
    String label,
    String value,
  ) {

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textLight,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 4),

          SelectableText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // AI RESULT ROW
  // =========================================================

  Widget _aiResultRow(
    String label,
    bool detected,
  ) {

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [

          Icon(
            detected
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: detected
                ? AppTheme.danger
                : AppTheme.success,
            size: 24,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),

          Text(
            detected
                ? 'DETECTED'
                : 'NOT DETECTED',
            style: TextStyle(
              color: detected
                  ? AppTheme.danger
                  : AppTheme.success,
              fontSize: 13,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // AI ANALYSIS CARD
  // =========================================================

  Widget _buildAiAnalysis() {

    final evidence =
        widget.evidence;

    final bool danger =
        evidence.dangerDetected;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(14),
              decoration:
                  BoxDecoration(
                color: danger
                    ? AppTheme.danger
                        .withOpacity(0.15)
                    : AppTheme.success
                        .withOpacity(0.15),
                borderRadius:
                    BorderRadius.circular(12),
                border: Border.all(
                  color: danger
                      ? AppTheme.danger
                      : AppTheme.success,
                ),
              ),
              child: Row(
                children: [

                  Icon(
                    danger
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    color: danger
                        ? AppTheme.danger
                        : AppTheme.success,
                    size: 32,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        Text(
                          danger
                              ? 'DANGER DETECTED'
                              : 'NO DANGER DETECTED',
                          style: TextStyle(
                            color: danger
                                ? AppTheme.danger
                                : AppTheme.success,
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          danger
                              ? 'Potentially dangerous activity detected'
                              : 'No potentially dangerous activity detected',
                          style:
                              const TextStyle(
                            color:
                                AppTheme.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _aiResultRow(
              'Violence',
              evidence.violenceDetected,
            ),

            _aiResultRow(
              'Knife',
              evidence.knifeDetected,
            ),

            _aiResultRow(
              'Gun',
              evidence.gunDetected,
            ),

            _aiResultRow(
              'Danger',
              evidence.dangerDetected,
            ),

            const Divider(
              height: 24,
            ),

            Row(
              children: [

                const Icon(
                  Icons.analytics_outlined,
                  color: AppTheme.accent,
                  size: 24,
                ),

                const SizedBox(width: 12),

                const Expanded(
                  child: Text(
                    'Violence Probability',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),

                Text(
                  '${(evidence.violenceProbability * 100).toStringAsFixed(2)}%',
                  style:
                      const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {

    final evidence =
        widget.evidence;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Evidence Details',
        ),
      ),

      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            const Text(
              'Evidence Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _buildVideoPlayer(),

            const SizedBox(height: 24),

            const Text(
              'Evidence Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    _detailRow(
                      'Evidence ID',
                      evidence.evidenceId,
                    ),

                    _detailRow(
                      'Filename',
                      evidence.filename,
                    ),

                    _detailRow(
                      'Upload Time',
                      evidence.uploadTime,
                    ),

                    _detailRow(
                      'Status',
                      evidence.status,
                    ),

                    _detailRow(
                      'SHA-256',
                      evidence.sha256,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'AI Analysis',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _buildAiAnalysis(),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _verifying
                        ? null
                        : _verifyNow,
                icon: _verifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.verified_outlined,
                      ),
                label: Text(
                  _verifying
                      ? 'Verifying...'
                      : 'Verify Evidence Integrity',
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_verifyResult != null)
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      const Text(
                        'Verification Result',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        _verifyResult.toString(),
                        style:
                            const TextStyle(
                          color:
                              AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}