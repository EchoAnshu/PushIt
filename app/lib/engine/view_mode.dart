import 'dart:math' as math;

import 'models.dart';

enum ViewMode { side, front }

double _distPx(
  Landmark a,
  Landmark b,
  double width,
  double height,
) {
  final dx = (a.x - b.x) * width;
  final dy = (a.y - b.y) * height;
  return math.sqrt(dx * dx + dy * dy);
}

bool _visible(List<Landmark> landmarks, List<int> indices, double minVisibility) {
  for (final index in indices) {
    if (landmarks[index].visibility < minVisibility) {
      return false;
    }
  }
  return true;
}

/// Torso length divided by shoulder width in image space.
/// Side view: shoulders overlap, torso is full length -> large ratio.
/// Front view: shoulders spread, torso foreshortened -> small ratio.
double? viewRatio(
  List<Landmark> landmarks,
  double width,
  double height, {
  double minVisibility = 0.4,
}) {
  if (!_visible(
    landmarks,
    [leftShoulder, rightShoulder, leftHip, rightHip],
    minVisibility,
  )) {
    return null;
  }
  final ls = landmarks[leftShoulder];
  final rs = landmarks[rightShoulder];
  final lh = landmarks[leftHip];
  final rh = landmarks[rightHip];

  final shoulderWidth = _distPx(ls, rs, width, height);
  if (shoulderWidth <= 1.0) {
    return null;
  }
  final shoulderMid = Landmark((ls.x + rs.x) / 2, (ls.y + rs.y) / 2, 1);
  final hipMid = Landmark((lh.x + rh.x) / 2, (lh.y + rh.y) / 2, 1);
  final torsoLength = _distPx(shoulderMid, hipMid, width, height);

  return torsoLength / shoulderWidth;
}

/// Returns side/front when confident, null in the ambiguous middle zone.
ViewMode? detectView(
  List<Landmark> landmarks,
  double width,
  double height, {
  double minVisibility = 0.4,
  double sideThreshold = 1.6,
  double frontThreshold = 1.2,
}) {
  final ratio = viewRatio(
    landmarks,
    width,
    height,
    minVisibility: minVisibility,
  );
  if (ratio == null) {
    return null;
  }
  if (ratio >= sideThreshold) {
    return ViewMode.side;
  }
  if (ratio <= frontThreshold) {
    return ViewMode.front;
  }
  return null;
}

/// Front-facing height metric: vertical distance between the nose and the
/// hands (wrists, or elbows as fallback), normalized by shoulder width.
/// Large at the top of the push-up, small at the bottom.
double? frontExtension(
  List<Landmark> landmarks,
  double width,
  double height, {
  double minVisibility = 0.35,
}) {
  final noseLandmark = landmarks[nose];
  if (!_visible(
    landmarks,
    [nose, leftShoulder, rightShoulder],
    minVisibility,
  )) {
    return null;
  }
  final shoulderWidth = _distPx(
    landmarks[leftShoulder],
    landmarks[rightShoulder],
    width,
    height,
  );
  if (shoulderWidth <= 1.0) {
    return null;
  }

  final wristYs = <double>[];
  for (final index in [leftWrist, rightWrist]) {
    final wrist = landmarks[index];
    if (wrist.visibility >= minVisibility) {
      wristYs.add(wrist.y * height);
    }
  }

  final handYs = <double>[];
  if (wristYs.isNotEmpty) {
    handYs.add(wristYs.reduce((a, b) => a + b) / wristYs.length);
  } else {
    final elbowYs = <double>[];
    for (final index in [leftElbow, rightElbow]) {
      final elbow = landmarks[index];
      if (elbow.visibility >= minVisibility) {
        elbowYs.add(elbow.y * height);
      }
    }
    if (elbowYs.isEmpty) {
      return null;
    }
    handYs.add(elbowYs.reduce((a, b) => a + b) / elbowYs.length);
  }

  final noseY = noseLandmark.y * height;
  return (handYs.first - noseY) / shoulderWidth;
}

/// Maps a calibrated front-view range [downValue, upValue] onto the
/// elbow-angle scale so the shared counter can consume it.
double pseudoAngle(double value, double downValue, double upValue) {
  if (upValue <= downValue) {
    return 95.0;
  }
  final t = ((value - downValue) / (upValue - downValue)).clamp(0.0, 1.0);
  return 95.0 + 65.0 * t;
}
