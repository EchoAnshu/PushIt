import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../engine/angles.dart' as angles;
import '../engine/calibration.dart';
import '../engine/counter.dart';
import '../engine/form_analyzer.dart';
import '../engine/models.dart';
import '../engine/posture.dart';
import '../engine/referee_config.dart';
import '../engine/view_mode.dart';
import '../storage/calibration_store.dart';
import '../vision/pose_camera.dart';
import '../vision/pose_service.dart';
import 'calibration_screen.dart';

class SoloScreen extends StatefulWidget {
  const SoloScreen({super.key});

  @override
  State<SoloScreen> createState() => _SoloScreenState();
}

class _SoloScreenState extends State<SoloScreen> {
  CalibrationData? _calibration;
  ViewMode _view = ViewMode.side;
  int _viewConfirm = 0;
  int _postureInvalidFrames = 0;
  int _lostFrames = 0;
  bool _wasTracked = false;

  late RefereeConfig _sideConfig;
  late RefereeConfig _frontConfig;
  late PushUpCounter _counter;
  late FormAnalyzer _analyzer;
  double _frontUp = kDefaultFrontUp;
  double _frontDown = kDefaultFrontDown;

  final AudioPlayer _ting = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _applyCalibration(null);
    _prepareSound();
    _loadCalibration();
  }

  Future<void> _prepareSound() async {
    try {
      await _ting.setSource(AssetSource('sounds/ting.wav'));
    } catch (_) {}
  }

  Future<void> _loadCalibration() async {
    final data = await CalibrationStore.load();
    if (!mounted || data == null) {
      return;
    }
    setState(() => _applyCalibration(data));
  }

  void _applyCalibration(CalibrationData? data) {
    _calibration = data;
    if (data == null) {
      _sideConfig = RefereeConfig.standard;
      _frontUp = kDefaultFrontUp;
      _frontDown = kDefaultFrontDown;
    } else {
      _sideConfig = calibratedSideConfig(data);
      _frontUp = data.frontUp;
      _frontDown = data.frontDown;
    }
    _frontConfig = frontModeConfig();
    _counter = PushUpCounter(config: _sideConfig);
    _analyzer = FormAnalyzer(config: _sideConfig);
  }

  Future<void> _openSetup() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CalibrationScreen()),
    );
    if (!mounted) {
      return;
    }
    if (saved == true) {
      final data = await CalibrationStore.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _applyCalibration(data);
        _postureInvalidFrames = 0;
        _wasTracked = false;
      });
    }
  }

  void _resetCount() {
    setState(() {
      _counter.reset();
      _analyzer.reset();
      _postureInvalidFrames = 0;
      _lostFrames = 0;
      _wasTracked = false;
    });
  }

  Future<void> _playTing() async {
    try {
      await _ting.seek(Duration.zero);
      await _ting.resume();
    } catch (_) {}
  }

  void _onResult(PoseResult? result) {
    double? presented; // elbow angle (side) or pseudo-angle (front)
    double? deviation;
    var postureRaw = true;

    if (result != null) {
      final landmarks = result.landmarks;
      final width = result.width;
      final height = result.height;

      final detected = detectView(landmarks, width, height);
      if (detected != null && detected != _view) {
        _viewConfirm += 1;
        final lockedMidRep = _counter.state == PushState.down;
        if (_viewConfirm >= (lockedMidRep ? 15 : 5)) {
          _view = detected;
          _viewConfirm = 0;
          _counter.config = _view == ViewMode.side ? _sideConfig : _frontConfig;
          _analyzer.config = _counter.config;
          _counter.resetCycle();
        }
      } else {
        _viewConfirm = 0;
      }

      if (_view == ViewMode.side) {
        final left = angles.sideAngle(
          landmarks,
          leftShoulder,
          leftElbow,
          leftWrist,
          width,
          height,
        );
        final right = angles.sideAngle(
          landmarks,
          rightShoulder,
          rightElbow,
          rightWrist,
          width,
          height,
        );
        presented = angles.combineAngles(left, right, _sideConfig.minVisibility);
        postureRaw = postureValid(landmarks, width, height, _sideConfig);
        deviation = bodyAlignmentDeviation(
          landmarks,
          width,
          height,
          _sideConfig.minVisibility,
        );
      } else {
        final value = frontExtension(
          landmarks,
          width,
          height,
          minVisibility: _frontConfig.minVisibility,
        );
        if (value != null) {
          presented = pseudoAngle(value, _frontDown, _frontUp);
        }
      }
    }

    if (postureRaw) {
      _postureInvalidFrames = 0;
    } else {
      _postureInvalidFrames += 1;
    }
    final postureOk =
        _postureInvalidFrames < _counter.config.postureInvalidGraceFrames;

    final tracked = presented != null && postureOk;
    _lostFrames = presented == null ? _lostFrames + 1 : 0;

    if (!postureOk) {
      _analyzer.feedback = CoachFeedback.moveIntoPushup;
    } else if (_lostFrames > _counter.config.landmarkLostFeedbackFrames) {
      _analyzer.feedback = CoachFeedback.moveIntoView;
    } else if (tracked && !_wasTracked) {
      _analyzer.feedback = CoachFeedback.ready;
    }
    _wasTracked = tracked;

    final state = _counter.update(
      presented,
      visible: presented != null,
      postureOk: postureOk && presented != null,
    );
    if (_counter.repCompleted) {
      _playTing();
    }
    _analyzer.update(
      _counter.smoothedAngle,
      state,
      _counter.repCompleted,
      _counter.incompleteEvent,
      deviation,
    );

    setState(() {});
  }

  @override
  void dispose() {
    _ting.dispose();
    super.dispose();
  }

  Color _feedbackColor(String feedback) {
    switch (feedback) {
      case CoachFeedback.goodRep:
        return const Color(0xFF16A34A);
      case CoachFeedback.incompleteRep:
        return const Color(0xFFEA580C);
      case CoachFeedback.goLower:
      case CoachFeedback.keepBackStraight:
      case CoachFeedback.goLowerAndBack:
        return const Color(0xFFF59E0B);
      case CoachFeedback.ready:
        return const Color(0xCC263238);
      default:
        return const Color(0xCC263238);
    }
  }

  Widget _stats() {
    final angle = _counter.smoothedAngle;
    final angleText = angle == null
        ? '--'
        : (_view == ViewMode.side
            ? '${angle.toStringAsFixed(0)}\u00B0'
            : angle.toStringAsFixed(0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_counter.count}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 64,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
        const Text(
          'REPS',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Good ${_analyzer.goodReps}   Bad ${_analyzer.incorrectReps}   '
          'Inc ${_counter.incompleteReps}',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          'angle $angleText   view ${_view.name}',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        if (_calibration == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Tip: tap Setup for accurate counting',
              style: TextStyle(color: Colors.amberAccent, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _actionButton(IconData icon, VoidCallback onPressed, String tooltip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PoseCamera(onResult: _onResult),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent, Colors.black54],
                stops: [0.0, 0.35, 1.0],
              ),
            ),
          ),
          Positioned(left: 20, top: 48, child: _stats()),
          Positioned(
            right: 12,
            top: 48,
            child: Column(
              children: [
                _actionButton(
                  Icons.tune,
                  _openSetup,
                  'Setup / calibrate',
                ),
                _actionButton(
                  Icons.refresh,
                  _resetCount,
                  'Reset count',
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(_analyzer.feedback + _counter.count.toString()),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _feedbackColor(_analyzer.feedback),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    _analyzer.feedback,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
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
