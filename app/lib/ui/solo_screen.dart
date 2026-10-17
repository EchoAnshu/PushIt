import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../engine/angles.dart' as angles;
import '../engine/counter.dart';
import '../engine/form_analyzer.dart';
import '../engine/models.dart';
import '../engine/posture.dart';
import '../engine/referee_config.dart';
import '../vision/pose_service.dart';

class SoloScreen extends StatefulWidget {
  const SoloScreen({super.key});

  @override
  State<SoloScreen> createState() => _SoloScreenState();
}

class _SoloScreenState extends State<SoloScreen> with WidgetsBindingObserver {
  static const _config = RefereeConfig.standard;

  final PoseService _poseService = PoseService();
  final PushUpCounter _counter = PushUpCounter(config: _config);
  final FormAnalyzer _analyzer = FormAnalyzer(config: _config);

  CameraController? _controller;
  bool _busy = false;
  String? _error;
  double _fps = 0.0;
  int _frameCount = 0;
  DateTime _fpsWindowStart = DateTime.now();
  int _postureInvalidFrames = 0;
  int _lostFrames = 0;
  bool _wasTracked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera found on this device.');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.startImageStream(_onFrame);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Camera error: $error');
      }
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final controller = _controller;
    if (controller == null || _busy) {
      return;
    }
    _busy = true;
    try {
      final input = _poseService.inputImageFromCamera(image, controller);
      PoseResult? result;
      if (input != null) {
        result = await _poseService.detect(input);
      }
      if (mounted) {
        _process(result);
      }
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  void _process(PoseResult? result) {
    double? angle;
    double? deviation;
    var postureRaw = true;

    if (result != null) {
      final landmarks = result.landmarks;
      final left = angles.sideAngle(
        landmarks,
        leftShoulder,
        leftElbow,
        leftWrist,
        result.width,
        result.height,
      );
      final right = angles.sideAngle(
        landmarks,
        rightShoulder,
        rightElbow,
        rightWrist,
        result.width,
        result.height,
      );
      angle = angles.combineAngles(left, right, _config.minVisibility);
      postureRaw = postureValid(
        landmarks,
        result.width,
        result.height,
        _config,
      );
      deviation = bodyAlignmentDeviation(
        landmarks,
        result.width,
        result.height,
        _config.minVisibility,
      );
    }

    if (postureRaw) {
      _postureInvalidFrames = 0;
    } else {
      _postureInvalidFrames += 1;
    }
    final postureOk =
        _postureInvalidFrames < _config.postureInvalidGraceFrames;

    final tracked = angle != null && postureOk;
    _lostFrames = angle != null ? 0 : _lostFrames + 1;

    if (!postureOk) {
      _analyzer.feedback = CoachFeedback.moveIntoPushup;
    } else if (_lostFrames > _config.landmarkLostFeedbackFrames) {
      _analyzer.feedback = CoachFeedback.moveIntoView;
    } else if (tracked && !_wasTracked) {
      _analyzer.feedback = CoachFeedback.ready;
    }
    _wasTracked = tracked;

    final state = _counter.update(
      angle,
      visible: angle != null,
      postureOk: postureOk,
    );
    _analyzer.update(
      _counter.smoothedAngle,
      state,
      _counter.repCompleted,
      _counter.incompleteEvent,
      deviation,
    );

    _frameCount += 1;
    final now = DateTime.now();
    final elapsed = now.difference(_fpsWindowStart).inMilliseconds;
    if (elapsed >= 1000) {
      _fps = _frameCount * 1000.0 / elapsed;
      _frameCount = 0;
      _fpsWindowStart = now;
    }

    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller = null;
      controller.dispose();
      setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _poseService.close();
    super.dispose();
  }

  Color _feedbackColor(String feedback) {
    if (feedback == CoachFeedback.goodRep) {
      return const Color(0xFF3CDC50);
    }
    if (feedback == CoachFeedback.incompleteRep) {
      return const Color(0xFF4646FF);
    }
    if (feedback == CoachFeedback.ready ||
        feedback == CoachFeedback.stepIntoView) {
      return const Color(0xFFAAAAAA);
    }
    return const Color(0xFF1EA5FF);
  }

  String _angleText(double? value) =>
      value == null ? ' --' : value.toStringAsFixed(0).padLeft(3);

  Widget _statsPanel() {
    final rows = <String>[
      'REPS: ${_counter.count}',
      'Good ${_analyzer.goodReps}  Bad ${_analyzer.incorrectReps}  '
          'Inc ${_counter.incompleteReps}',
      'State: ${_counter.state.name.toUpperCase()}',
      'Angle ${_angleText(_counter.smoothedAngle)}  '
          'FPS ${_fps.toStringAsFixed(1)}',
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            Text(
              row,
              style: TextStyle(
                color: Colors.white,
                fontSize: row.startsWith('REPS') ? 26 : 14,
                fontWeight:
                    row.startsWith('REPS') ? FontWeight.bold : FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null)
            CameraPreview(controller)
          else
            Center(
              child: Text(
                _error ?? 'Starting camera...',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          Positioned(left: 12, top: 12, child: _statsPanel()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _feedbackColor(_analyzer.feedback)
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _analyzer.feedback,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

