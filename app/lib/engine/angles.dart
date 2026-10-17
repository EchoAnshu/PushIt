import 'dart:math' as math;

import 'models.dart';

class Vec2 {
  final double x;
  final double y;

  const Vec2(this.x, this.y);
}

class SideAngle {
  final double angle;
  final double visibility;

  const SideAngle(this.angle, this.visibility);
}

double calculateAngle(Vec2 a, Vec2 b, Vec2 c) {
  final bax = a.x - b.x;
  final bay = a.y - b.y;
  final bcx = c.x - b.x;
  final bcy = c.y - b.y;

  final dot = bax * bcx + bay * bcy;
  final magnitude =
      math.sqrt(bax * bax + bay * bay) * math.sqrt(bcx * bcx + bcy * bcy);
  if (magnitude == 0.0) {
    return 0.0;
  }

  final cosine = (dot / magnitude).clamp(-1.0, 1.0);
  return math.acos(cosine) * 180.0 / math.pi;
}

SideAngle sideAngle(
  List<Landmark> landmarks,
  int shoulderIndex,
  int elbowIndex,
  int wristIndex,
  double width,
  double height,
) {
  final shoulder = landmarks[shoulderIndex];
  final elbow = landmarks[elbowIndex];
  final wrist = landmarks[wristIndex];

  final visibility = [
    shoulder.visibility,
    elbow.visibility,
    wrist.visibility,
  ].reduce((a, b) => a < b ? a : b);

  final angle = calculateAngle(
    Vec2(shoulder.x * width, shoulder.y * height),
    Vec2(elbow.x * width, elbow.y * height),
    Vec2(wrist.x * width, wrist.y * height),
  );
  return SideAngle(angle, visibility);
}

double? combineAngles(
  SideAngle left,
  SideAngle right,
  double minVisibility,
) {
  final candidates = <double>[
    if (left.visibility >= minVisibility) left.angle,
    if (right.visibility >= minVisibility) right.angle,
  ];
  if (candidates.isEmpty) {
    return null;
  }
  return candidates.reduce((a, b) => a + b) / candidates.length;
}
