import 'dart:math' as math;

import 'models.dart';
import 'referee_config.dart';

class _Midpoint {
  final double x;
  final double y;

  const _Midpoint(this.x, this.y);
}

_Midpoint? _midpoint(
  List<Landmark> landmarks,
  List<int> indices,
  double minVisibility,
) {
  for (final index in indices) {
    if (landmarks[index].visibility < minVisibility) {
      return null;
    }
  }
  var x = 0.0;
  var y = 0.0;
  for (final index in indices) {
    x += landmarks[index].x;
    y += landmarks[index].y;
  }
  return _Midpoint(x / indices.length, y / indices.length);
}

const _sides = [
  [leftShoulder, leftElbow, leftWrist],
  [rightShoulder, rightElbow, rightWrist],
];

bool postureValid(
  List<Landmark> landmarks,
  double width,
  double height,
  RefereeConfig config,
) {
  for (final side in _sides) {
    final shoulder = landmarks[side[0]];
    final elbow = landmarks[side[1]];
    final wrist = landmarks[side[2]];
    if ([shoulder.visibility, elbow.visibility, wrist.visibility]
            .reduce((a, b) => a < b ? a : b) <
        config.minVisibility) {
      continue;
    }
    final shoulderX = shoulder.x * width;
    final shoulderY = shoulder.y * height;
    final elbowX = elbow.x * width;
    final elbowY = elbow.y * height;
    final wristY = wrist.y * height;
    final upperArm = math.sqrt(
      math.pow(elbowX - shoulderX, 2) + math.pow(elbowY - shoulderY, 2),
    );
    if (upperArm <= 0.0) {
      continue;
    }
    final wristRise = -(wristY - shoulderY) / upperArm;
    if (wristRise > config.postureWristOverheadFraction) {
      return false;
    }
  }

  final shoulder = _midpoint(
    landmarks,
    const [leftShoulder, rightShoulder],
    config.minVisibility,
  );
  final hip = _midpoint(
    landmarks,
    const [leftHip, rightHip],
    config.minVisibility,
  );
  if (shoulder == null || hip == null) {
    return true;
  }

  final shoulderX = shoulder.x * width;
  final shoulderY = shoulder.y * height;
  final hipX = hip.x * width;
  final hipY = hip.y * height;
  final torso = math.sqrt(
    math.pow(hipX - shoulderX, 2) + math.pow(hipY - shoulderY, 2),
  );
  if (torso <= 0.0) {
    return true;
  }

  if (shoulderY < hipY &&
      (hipY - shoulderY) / torso > config.pushupMaxTorsoVerticality) {
    return false;
  }

  for (final side in _sides) {
    final shoulderPoint = landmarks[side[0]];
    final elbow = landmarks[side[1]];
    final wrist = landmarks[side[2]];
    if ([shoulderPoint.visibility, elbow.visibility, wrist.visibility]
            .reduce((a, b) => a < b ? a : b) <
        config.minVisibility) {
      continue;
    }
    final handDepth = (wrist.y * height - hipY) / torso;
    if (handDepth < config.pushupMinHandDepthFraction) {
      return false;
    }
  }
  return true;
}

double? bodyAlignmentDeviation(
  List<Landmark> landmarks,
  double width,
  double height,
  double minVisibility,
) {
  const indices = [
    leftShoulder,
    rightShoulder,
    leftHip,
    rightHip,
    leftAnkle,
    rightAnkle,
  ];
  for (final index in indices) {
    if (landmarks[index].visibility < minVisibility) {
      return null;
    }
  }

  final shoulderX =
      (landmarks[leftShoulder].x + landmarks[rightShoulder].x) / 2.0;
  final shoulderY =
      (landmarks[leftShoulder].y + landmarks[rightShoulder].y) / 2.0;
  final hipX = (landmarks[leftHip].x + landmarks[rightHip].x) / 2.0;
  final hipY = (landmarks[leftHip].y + landmarks[rightHip].y) / 2.0;
  final ankleX =
      (landmarks[leftAnkle].x + landmarks[rightAnkle].x) / 2.0;
  final ankleY =
      (landmarks[leftAnkle].y + landmarks[rightAnkle].y) / 2.0;

  final lineX = (ankleX - shoulderX) * width;
  final lineY = (ankleY - shoulderY) * height;
  final sideX = (hipX - shoulderX) * width;
  final sideY = (hipY - shoulderY) * height;

  final lengthSq = lineX * lineX + lineY * lineY;
  if (lengthSq <= 0.0) {
    return null;
  }
  final perpendicular = (lineX * sideY - lineY * sideX).abs();
  return perpendicular / lengthSq;
}
