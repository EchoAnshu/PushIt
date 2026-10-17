import 'referee_config.dart';

class CalibrationData {
  final double sideUp;
  final double sideDown;
  final double frontUp;
  final double frontDown;

  const CalibrationData({
    required this.sideUp,
    required this.sideDown,
    required this.frontUp,
    required this.frontDown,
  });

  bool get isValid =>
      sideUp - sideDown >= 15.0 && frontUp - frontDown >= 0.25;

  Map<String, dynamic> toJson() => {
        'sideUp': sideUp,
        'sideDown': sideDown,
        'frontUp': frontUp,
        'frontDown': frontDown,
      };

  factory CalibrationData.fromJson(Map<String, dynamic> json) {
    return CalibrationData(
      sideUp: (json['sideUp'] as num).toDouble(),
      sideDown: (json['sideDown'] as num).toDouble(),
      frontUp: (json['frontUp'] as num).toDouble(),
      frontDown: (json['frontDown'] as num).toDouble(),
    );
  }
}

/// Side-view counting thresholds derived from the user's own top/bottom
/// elbow angles. The exercise must reach within ~8 degrees of each hold.
RefereeConfig calibratedSideConfig(CalibrationData data) {
  final up = (data.sideUp - 8.0).clamp(120.0, 165.0);
  var down = (data.sideDown + 8.0).clamp(90.0, 135.0);
  if (down > up - 20.0) {
    down = up - 20.0;
  }
  return RefereeConfig.standard.copyWith(
    elbowUpAngle: up,
    elbowDownAngle: down,
    goodDepthAngle: down + 5.0,
    postureInvalidGraceFrames: 10,
    pushupMaxTorsoVerticality: 0.9,
  );
}

/// Front-view counting thresholds. The front metric is mapped onto a
/// pseudo elbow-angle range [95, 160] by `pseudoAngle`.
RefereeConfig frontModeConfig() {
  return RefereeConfig.standard.copyWith(
    elbowUpAngle: 152.0,
    elbowDownAngle: 102.0,
    goodDepthAngle: 112.0,
    angleSmoothing: 0.55,
    alignmentMaxDeviation: 1.0,
    incompleteDropFromUp: 20.0,
  );
}

const double kDefaultFrontUp = 2.2;
const double kDefaultFrontDown = 0.8;
