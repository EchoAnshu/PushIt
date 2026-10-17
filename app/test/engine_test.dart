import 'package:flutter_test/flutter_test.dart';
import 'package:pushit_battle/engine/angles.dart';
import 'package:pushit_battle/engine/calibration.dart';
import 'package:pushit_battle/engine/counter.dart';
import 'package:pushit_battle/engine/form_analyzer.dart';
import 'package:pushit_battle/engine/models.dart';
import 'package:pushit_battle/engine/posture.dart';
import 'package:pushit_battle/engine/referee_config.dart';
import 'package:pushit_battle/engine/view_mode.dart';

List<Landmark> landmarksFrom(Map<int, List<double>> points) {
  final list = List<Landmark>.generate(
    landmarkCount,
    (_) => const Landmark(0.5, 0.5, 0.0),
  );
  points.forEach((index, point) {
    list[index] = Landmark(point[0], point[1], 0.9);
  });
  return list;
}

void feed(PushUpCounter counter, double angle, int frames) {
  for (var i = 0; i < frames; i++) {
    counter.update(angle);
  }
}

void main() {
  group('calculateAngle', () {
    test('right angle', () {
      expect(
        calculateAngle(
          const Vec2(0, 100),
          const Vec2(0, 0),
          const Vec2(100, 0),
        ),
        closeTo(90.0, 0.001),
      );
    });

    test('straight arm', () {
      expect(
        calculateAngle(
          const Vec2(-100, 0),
          const Vec2(0, 0),
          const Vec2(100, 0),
        ),
        closeTo(180.0, 0.001),
      );
    });
  });

  group('postureValid', () {
    const width = 1000.0;
    const height = 1000.0;
    const config = RefereeConfig.standard;

    test('rejects standing curls', () {
      final landmarks = landmarksFrom({
        leftShoulder: [0.45, 0.2],
        rightShoulder: [0.55, 0.2],
        leftElbow: [0.45, 0.4],
        rightElbow: [0.55, 0.4],
        leftWrist: [0.45, 0.6],
        rightWrist: [0.55, 0.6],
        leftHip: [0.46, 0.5],
        rightHip: [0.54, 0.5],
      });
      expect(postureValid(landmarks, width, height, config), isFalse);
    });

    test('accepts plank position', () {
      final landmarks = landmarksFrom({
        leftShoulder: [0.30, 0.50],
        rightShoulder: [0.32, 0.50],
        leftElbow: [0.30, 0.60],
        rightElbow: [0.32, 0.60],
        leftWrist: [0.30, 0.70],
        rightWrist: [0.32, 0.70],
        leftHip: [0.60, 0.52],
        rightHip: [0.62, 0.52],
      });
      expect(postureValid(landmarks, width, height, config), isTrue);
    });

    test('rejects overhead arms', () {
      final landmarks = landmarksFrom({
        leftShoulder: [0.45, 0.50],
        rightShoulder: [0.55, 0.50],
        leftElbow: [0.45, 0.35],
        rightElbow: [0.55, 0.35],
        leftWrist: [0.45, 0.10],
        rightWrist: [0.55, 0.10],
        leftHip: [0.46, 0.52],
        rightHip: [0.54, 0.52],
      });
      expect(postureValid(landmarks, width, height, config), isFalse);
    });
  });

  group('PushUpCounter', () {
    test('counts a full rep', () {
      final counter = PushUpCounter(config: RefereeConfig.standard);
      feed(counter, 170, 10);
      feed(counter, 90, 10);
      var completed = false;
      for (var i = 0; i < 10; i++) {
        counter.update(170);
        completed = completed || counter.repCompleted;
      }
      expect(counter.count, 1);
      expect(completed, isTrue);
    });

    test('does not count incomplete rep', () {
      final counter = PushUpCounter(config: RefereeConfig.standard);
      feed(counter, 170, 10);
      feed(counter, 128, 10);
      var incomplete = false;
      for (var i = 0; i < 10; i++) {
        counter.update(170);
        incomplete = incomplete || counter.incompleteEvent;
      }
      expect(counter.count, 0);
      expect(counter.incompleteReps, 1);
      expect(incomplete, isTrue);
    });

    test('invalid posture resets the cycle', () {
      final counter = PushUpCounter(config: RefereeConfig.standard);
      feed(counter, 170, 10);
      feed(counter, 90, 5);
      counter.update(90, postureOk: false);
      feed(counter, 170, 10);
      expect(counter.count, 0);
    });

    test('lost visibility beyond grace resets the cycle', () {
      final counter = PushUpCounter(config: RefereeConfig.standard);
      feed(counter, 170, 10);
      feed(counter, 90, 5);
      for (var i = 0; i <= RefereeConfig.standard.landmarkLostGraceFrames; i++) {
        counter.update(null, visible: false);
      }
      feed(counter, 170, 10);
      expect(counter.count, 0);
    });
  });

  group('FormAnalyzer', () {
    test('grades a good rep', () {
      final analyzer = FormAnalyzer(config: RefereeConfig.standard);
      analyzer.update(170, PushState.up, false, false, 0.05);
      analyzer.update(85, PushState.down, false, false, 0.05);
      analyzer.update(170, PushState.up, true, false, 0.05);
      expect(analyzer.goodReps, 1);
      expect(analyzer.feedback, CoachFeedback.goodRep);
    });

    test('flags shallow reps', () {
      final analyzer = FormAnalyzer(config: RefereeConfig.standard);
      analyzer.update(170, PushState.up, false, false, 0.05);
      analyzer.update(120, PushState.down, false, false, 0.05);
      analyzer.update(170, PushState.up, true, false, 0.05);
      expect(analyzer.incorrectReps, 1);
      expect(analyzer.feedback, CoachFeedback.goLower);
    });

    test('flags sagging hips', () {
      final analyzer = FormAnalyzer(config: RefereeConfig.standard);
      analyzer.update(170, PushState.up, false, false, 0.05);
      analyzer.update(80, PushState.down, false, false, 0.30);
      analyzer.update(170, PushState.up, true, false, 0.30);
      expect(analyzer.incorrectReps, 1);
      expect(analyzer.feedback, CoachFeedback.keepBackStraight);
    });
  });

  group('detectView', () {
    const width = 1000.0;
    const height = 1000.0;

    test('detects side view (shoulders overlapping, long torso)', () {
      final landmarks = landmarksFrom({
        leftShoulder: [0.50, 0.30],
        rightShoulder: [0.52, 0.30],
        leftHip: [0.50, 0.85],
        rightHip: [0.53, 0.85],
      });
      expect(
        detectView(landmarks, width, height),
        ViewMode.side,
      );
    });

    test('detects front view (wide shoulders, foreshortened torso)', () {
      final landmarks = landmarksFrom({
        leftShoulder: [0.25, 0.30],
        rightShoulder: [0.75, 0.30],
        leftHip: [0.35, 0.55],
        rightHip: [0.65, 0.55],
      });
      expect(
        detectView(landmarks, width, height),
        ViewMode.front,
      );
    });

    test('returns null when landmarks are not visible', () {
      final landmarks = landmarksFrom({});
      expect(detectView(landmarks, width, height), isNull);
    });
  });

  group('frontExtension', () {
    const width = 1000.0;
    const height = 1000.0;

    test('top position gives a large value', () {
      final landmarks = landmarksFrom({
        nose: [0.5, 0.2],
        leftShoulder: [0.2, 0.35],
        rightShoulder: [0.8, 0.35],
        leftWrist: [0.45, 0.9],
        rightWrist: [0.55, 0.9],
      });
      final value = frontExtension(landmarks, width, height);
      expect(value, closeTo((0.9 - 0.2) / 0.6, 0.01));
    });

    test('bottom position gives a smaller value', () {
      final landmarks = landmarksFrom({
        nose: [0.5, 0.75],
        leftShoulder: [0.2, 0.8],
        rightShoulder: [0.8, 0.8],
        leftWrist: [0.45, 0.95],
        rightWrist: [0.55, 0.95],
      });
      final value = frontExtension(landmarks, width, height);
      expect(value, closeTo((0.95 - 0.75) / 0.6, 0.02));
    });
  });

  group('pseudoAngle', () {
    test('maps the calibrated range onto 95..160', () {
      expect(pseudoAngle(2.0, 2.0, 3.0), closeTo(95.0, 0.001));
      expect(pseudoAngle(3.0, 2.0, 3.0), closeTo(160.0, 0.001));
      expect(pseudoAngle(2.5, 2.0, 3.0), closeTo(127.5, 0.001));
    });

    test('clamps outside the range', () {
      expect(pseudoAngle(1.0, 2.0, 3.0), closeTo(95.0, 0.001));
      expect(pseudoAngle(4.0, 2.0, 3.0), closeTo(160.0, 0.001));
    });
  });

  group('calibratedSideConfig', () {
    test('derives thresholds from the user range', () {
      const data = CalibrationData(
        sideUp: 170,
        sideDown: 95,
        frontUp: 2.0,
        frontDown: 1.0,
      );
      final config = calibratedSideConfig(data);
      expect(config.elbowUpAngle, closeTo(162, 0.001));
      expect(config.elbowDownAngle, closeTo(103, 0.001));
      expect(config.goodDepthAngle, closeTo(108, 0.001));
      expect(data.isValid, isTrue);
    });

    test('keeps a 20 degree gap between thresholds', () {
      const data = CalibrationData(
        sideUp: 130,
        sideDown: 120,
        frontUp: 2.0,
        frontDown: 1.0,
      );
      final config = calibratedSideConfig(data);
      expect(
        config.elbowUpAngle - config.elbowDownAngle,
        greaterThanOrEqualTo(20.0),
      );
    });
  });
}

