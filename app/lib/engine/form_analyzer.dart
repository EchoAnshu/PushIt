import 'counter.dart';
import 'referee_config.dart';

class CoachFeedback {
  static const stepIntoView = 'Step into view';
  static const ready = 'Ready';
  static const moveIntoPushup = 'Move into push-up position';
  static const moveIntoView = 'Move fully into view';
  static const goodRep = 'Good Rep';
  static const incompleteRep = 'Incomplete Rep';
  static const goLower = 'Go Lower';
  static const keepBackStraight = 'Keep Your Back Straight';
  static const goLowerAndBack = 'Go Lower  -  Keep Your Back Straight';
}

class FormAnalyzer {
  RefereeConfig config;

  String feedback = CoachFeedback.stepIntoView;
  int goodReps = 0;
  int incorrectReps = 0;
  double? lastMinAngle;
  double? lastMaxDeviation;
  double? _cycleMinAngle;
  double _cycleMaxDeviation = 0.0;
  PushState _prevState = PushState.unknown;
  bool _cycleOpen = false;

  FormAnalyzer({this.config = RefereeConfig.standard});

  void reset() {
    feedback = CoachFeedback.stepIntoView;
    goodReps = 0;
    incorrectReps = 0;
    lastMinAngle = null;
    lastMaxDeviation = null;
    _cycleMinAngle = null;
    _cycleMaxDeviation = 0.0;
    _prevState = PushState.unknown;
    _cycleOpen = false;
  }

  void _openCycle() {
    _cycleMinAngle = null;
    _cycleMaxDeviation = 0.0;
    _cycleOpen = true;
  }

  String update(
    double? angle,
    PushState state,
    bool repCompleted,
    bool incompleteEvent,
    double? deviation,
  ) {
    if (state == PushState.unknown) {
      _cycleOpen = false;
      _cycleMinAngle = null;
      _cycleMaxDeviation = 0.0;
    } else if (state == PushState.down && _prevState != PushState.down) {
      _openCycle();
    }
    _prevState = state;

    if (_cycleOpen) {
      if (angle != null) {
        final current = _cycleMinAngle;
        _cycleMinAngle = current == null ? angle : (angle < current ? angle : current);
      }
      if (deviation != null && deviation > _cycleMaxDeviation) {
        _cycleMaxDeviation = deviation;
      }
    }

    if (repCompleted) {
      _finalizeRep();
    } else if (incompleteEvent) {
      feedback = CoachFeedback.incompleteRep;
    }

    return feedback;
  }

  void _finalizeRep() {
    _cycleOpen = false;
    final minAngle = _cycleMinAngle;
    final maxDeviation = _cycleMaxDeviation;
    lastMinAngle = minAngle;
    lastMaxDeviation = maxDeviation;

    final depthOk = minAngle != null && minAngle <= config.goodDepthAngle;
    final alignmentOk = maxDeviation <= config.alignmentMaxDeviation;

    if (depthOk && alignmentOk) {
      goodReps += 1;
      feedback = CoachFeedback.goodRep;
      return;
    }

    incorrectReps += 1;
    if (!depthOk && !alignmentOk) {
      feedback = CoachFeedback.goLowerAndBack;
    } else if (!depthOk) {
      feedback = CoachFeedback.goLower;
    } else {
      feedback = CoachFeedback.keepBackStraight;
    }
  }
}


