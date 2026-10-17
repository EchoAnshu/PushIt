import 'package:flutter/material.dart';

import '../engine/angles.dart' as angles;
import '../engine/calibration.dart';
import '../engine/models.dart';
import '../engine/referee_config.dart';
import '../engine/view_mode.dart';
import '../storage/calibration_store.dart';
import '../vision/pose_camera.dart';
import '../vision/pose_service.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  static const _prepareMs = 2500;
  static const _collectMs = 3000;
  static const _phases = <_Phase>[
    _Phase(
      title: 'Side view - TOP',
      detail:
          'Place the phone on the floor to your side, get in push-up position '
          'and hold the top with arms locked out.',
      frontView: false,
    ),
    _Phase(
      title: 'Side view - BOTTOM',
      detail: 'Stay side-on. Lower down and hold with your chest near the floor.',
      frontView: false,
    ),
    _Phase(
      title: 'Front view - TOP',
      detail:
          'Move the phone in front of you and face it. Get in push-up position '
          'and hold the top with arms locked out.',
      frontView: true,
    ),
    _Phase(
      title: 'Front view - BOTTOM',
      detail: 'Stay facing the phone. Lower down and hold near the floor.',
      frontView: true,
    ),
  ];

  int _phaseIndex = 0;
  late DateTime _phaseStart;
  final List<double> _samples = [];
  final List<double> _results = [];
  double? _liveValue;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _phaseStart = DateTime.now();
  }

  _Phase get _phase => _phases[_phaseIndex];

  void _onResult(PoseResult? result) {
    if (_saved || _error != null) {
      return;
    }
    final elapsed = DateTime.now().difference(_phaseStart).inMilliseconds;

    if (elapsed < _prepareMs) {
      setState(() {});
      return;
    }

    if (result != null) {
      final value = _measure(result);
      if (value != null) {
        _samples.add(value);
        _liveValue = value;
      }
    }

    if (elapsed >= _prepareMs + _collectMs) {
      _advance();
      return;
    }
    setState(() {});
  }

  double? _measure(PoseResult result) {
    if (_phase.frontView) {
      return frontExtension(
        result.landmarks,
        result.width,
        result.height,
        minVisibility: 0.3,
      );
    }
    const config = RefereeConfig.standard;
    final left = angles.sideAngle(
      result.landmarks,
      leftShoulder,
      leftElbow,
      leftWrist,
      result.width,
      result.height,
    );
    final right = angles.sideAngle(
      result.landmarks,
      rightShoulder,
      rightElbow,
      rightWrist,
      result.width,
      result.height,
    );
    return angles.combineAngles(left, right, config.minVisibility);
  }

  void _advance() {
    if (_samples.length < 4) {
      setState(() {
        _error = 'Could not see you properly. Keep your whole body in frame '
            'and try again.';
      });
      return;
    }
    final mean = _samples.reduce((a, b) => a + b) / _samples.length;
    _results.add(mean);
    _samples.clear();
    _liveValue = null;

    if (_phaseIndex < _phases.length - 1) {
      setState(() {
        _phaseIndex += 1;
        _phaseStart = DateTime.now();
      });
      return;
    }

    final data = CalibrationData(
      sideUp: _results[0],
      sideDown: _results[1],
      frontUp: _results[2],
      frontDown: _results[3],
    );
    if (!data.isValid) {
      setState(() {
        _error = 'The measured positions look off. Make sure TOP has straight '
            'arms and BOTTOM is close to the floor, then try again.';
      });
      return;
    }
    CalibrationStore.save(data).then((_) {
      if (mounted) {
        setState(() => _saved = true);
        Navigator.of(context).pop(true);
      }
    });
  }

  void _retry() {
    setState(() {
      _phaseIndex = 0;
      _phaseStart = DateTime.now();
      _samples.clear();
      _results.clear();
      _liveValue = null;
      _error = null;
    });
  }

  Widget _card() {
    final bool preparing =
        DateTime.now().difference(_phaseStart).inMilliseconds < _prepareMs;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Setup ${_phaseIndex + 1}/${_phases.length}',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            _phase.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _phase.detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 14),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _retry,
              child: const Text('Retry'),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  preparing ? Icons.timer_outlined : Icons.check_circle_outline,
                  color: preparing ? Colors.orangeAccent : Colors.greenAccent,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  preparing ? 'Get ready and hold still...' : 'Hold it...',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _liveValue == null
                  ? '--'
                  : (_phase.frontView
                      ? _liveValue!.toStringAsFixed(2)
                      : '${_liveValue!.toStringAsFixed(0)} deg'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
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
                colors: [Colors.black54, Colors.transparent, Colors.black87],
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _card(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: LinearProgressIndicator(
                    value: (_phaseIndex + 1) / _phases.length,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Phase {
  final String title;
  final String detail;
  final bool frontView;

  const _Phase({
    required this.title,
    required this.detail,
    required this.frontView,
  });
}
