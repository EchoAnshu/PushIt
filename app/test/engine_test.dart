import 'package:flutter_test/flutter_test.dart';
import 'package:pushit_battle/engine/angles.dart';
import 'package:pushit_battle/engine/counter.dart';
import 'package:pushit_battle/engine/form_analyzer.dart';
import 'package:pushit_battle/engine/models.dart';
import 'package:pushit_battle/engine/posture.dart';
import 'package:pushit_battle/engine/referee_config.dart';

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
      expect(analyzer.feedback, Feedback.goodRep);
    });

    test('flags shallow reps', () {
      final analyzer = FormAnalyzer(config: RefereeConfig.standard);
      analyzer.update(170, PushState.up, false, false, 0.05);
      analyzer.update(120, PushState.down, false, false, 0.05);
      analyzer.update(170, PushState.up, true, false, 0.05);
      expect(analyzer.incorrectReps, 1);
      expect(analyzer.feedback, Feedback.goLower);
    });

    test('flags sagging hips', () {
      final analyzer = FormAnalyzer(config: RefereeConfig.standard);
      analyzer.update(170, PushState.up, false, false, 0.05);
      analyzer.update(80, PushState.down, false, false, 0.30);
      analyzer.update(170, PushState.up, true, false, 0.30);
      expect(analyzer.incorrectReps, 1);
      expect(analyzer.feedback, Feedback.keepBackStraight);
    });
  });
}
