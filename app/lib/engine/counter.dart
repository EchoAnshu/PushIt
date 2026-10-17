import 'referee_config.dart';

enum PushState { up, down, unknown }

class PushUpCounter {
  final RefereeConfig config;

  PushState state = PushState.unknown;
  int count = 0;
  bool repCompleted = false;
  int incompleteReps = 0;
  bool incompleteEvent = false;
  double? smoothedAngle;
  int lostFrames = 0;
  bool _attemptDrop = false;

  PushUpCounter({this.config = RefereeConfig.standard});

  void reset() {
    state = PushState.unknown;
    count = 0;
    repCompleted = false;
    incompleteReps = 0;
    incompleteEvent = false;
    smoothedAngle = null;
    lostFrames = 0;
    _attemptDrop = false;
  }

  void _resetCycle() {
    state = PushState.unknown;
    smoothedAngle = null;
    _attemptDrop = false;
  }

  PushState _handleLoss() {
    lostFrames += 1;
    if (lostFrames > config.landmarkLostGraceFrames) {
      lostFrames = 0;
      _resetCycle();
    }
    return state;
  }

  double _smooth(double angle) {
    final current = smoothedAngle;
    if (current == null) {
      smoothedAngle = angle;
    } else {
      smoothedAngle = config.angleSmoothing * angle +
          (1.0 - config.angleSmoothing) * current;
    }
    return smoothedAngle!;
  }

  PushState update(
    double? elbowAngle, {
    bool visible = true,
    bool postureOk = true,
  }) {
    repCompleted = false;
    incompleteEvent = false;

    if (!postureOk) {
      lostFrames = 0;
      _resetCycle();
      return state;
    }

    if (!visible || elbowAngle == null) {
      return _handleLoss();
    }

    lostFrames = 0;
    final angle = _smooth(elbowAngle);

    if (angle >= config.elbowUpAngle) {
      final wasDown = state == PushState.down;
      state = PushState.up;
      if (wasDown) {
        count += 1;
        repCompleted = true;
      }
      if (_attemptDrop) {
        incompleteReps += 1;
        incompleteEvent = true;
        _attemptDrop = false;
      }
    } else if (angle <= config.elbowDownAngle) {
      _attemptDrop = false;
      state = PushState.down;
    } else if (state == PushState.up) {
      if (angle < config.elbowUpAngle - config.incompleteDropFromUp) {
        _attemptDrop = true;
      }
    }

    return state;
  }
}
