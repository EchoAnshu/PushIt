class RefereeConfig {
  final double minVisibility;
  final int landmarkLostGraceFrames;
  final int landmarkLostFeedbackFrames;
  final double postureWristOverheadFraction;
  final double pushupMinHandDepthFraction;
  final double pushupMaxTorsoVerticality;
  final int postureInvalidGraceFrames;
  final double goodDepthAngle;
  final double alignmentMaxDeviation;
  final double incompleteDropFromUp;
  final double elbowUpAngle;
  final double elbowDownAngle;
  final double angleSmoothing;
  final int tempoCapMs;

  const RefereeConfig({
    required this.minVisibility,
    required this.landmarkLostGraceFrames,
    required this.landmarkLostFeedbackFrames,
    required this.postureWristOverheadFraction,
    required this.pushupMinHandDepthFraction,
    required this.pushupMaxTorsoVerticality,
    required this.postureInvalidGraceFrames,
    required this.goodDepthAngle,
    required this.alignmentMaxDeviation,
    required this.incompleteDropFromUp,
    required this.elbowUpAngle,
    required this.elbowDownAngle,
    required this.angleSmoothing,
    required this.tempoCapMs,
  });

  RefereeConfig copyWith({
    double? minVisibility,
    int? landmarkLostGraceFrames,
    int? landmarkLostFeedbackFrames,
    double? postureWristOverheadFraction,
    double? pushupMinHandDepthFraction,
    double? pushupMaxTorsoVerticality,
    int? postureInvalidGraceFrames,
    double? goodDepthAngle,
    double? alignmentMaxDeviation,
    double? incompleteDropFromUp,
    double? elbowUpAngle,
    double? elbowDownAngle,
    double? angleSmoothing,
    int? tempoCapMs,
  }) {
    return RefereeConfig(
      minVisibility: minVisibility ?? this.minVisibility,
      landmarkLostGraceFrames:
          landmarkLostGraceFrames ?? this.landmarkLostGraceFrames,
      landmarkLostFeedbackFrames:
          landmarkLostFeedbackFrames ?? this.landmarkLostFeedbackFrames,
      postureWristOverheadFraction:
          postureWristOverheadFraction ?? this.postureWristOverheadFraction,
      pushupMinHandDepthFraction:
          pushupMinHandDepthFraction ?? this.pushupMinHandDepthFraction,
      pushupMaxTorsoVerticality:
          pushupMaxTorsoVerticality ?? this.pushupMaxTorsoVerticality,
      postureInvalidGraceFrames:
          postureInvalidGraceFrames ?? this.postureInvalidGraceFrames,
      goodDepthAngle: goodDepthAngle ?? this.goodDepthAngle,
      alignmentMaxDeviation:
          alignmentMaxDeviation ?? this.alignmentMaxDeviation,
      incompleteDropFromUp: incompleteDropFromUp ?? this.incompleteDropFromUp,
      elbowUpAngle: elbowUpAngle ?? this.elbowUpAngle,
      elbowDownAngle: elbowDownAngle ?? this.elbowDownAngle,
      angleSmoothing: angleSmoothing ?? this.angleSmoothing,
      tempoCapMs: tempoCapMs ?? this.tempoCapMs,
    );
  }

  static const lenient = RefereeConfig(
    minVisibility: 0.3,
    landmarkLostGraceFrames: 15,
    landmarkLostFeedbackFrames: 30,
    postureWristOverheadFraction: 0.25,
    pushupMinHandDepthFraction: 0.30,
    pushupMaxTorsoVerticality: 0.85,
    postureInvalidGraceFrames: 5,
    goodDepthAngle: 105.0,
    alignmentMaxDeviation: 0.24,
    incompleteDropFromUp: 15.0,
    elbowUpAngle: 150.0,
    elbowDownAngle: 110.0,
    angleSmoothing: 0.55,
    tempoCapMs: 350,
  );

  static const standard = RefereeConfig(
    minVisibility: 0.3,
    landmarkLostGraceFrames: 15,
    landmarkLostFeedbackFrames: 30,
    postureWristOverheadFraction: 0.2,
    pushupMinHandDepthFraction: 0.35,
    pushupMaxTorsoVerticality: 0.75,
    postureInvalidGraceFrames: 5,
    goodDepthAngle: 90.0,
    alignmentMaxDeviation: 0.18,
    incompleteDropFromUp: 20.0,
    elbowUpAngle: 155.0,
    elbowDownAngle: 100.0,
    angleSmoothing: 0.65,
    tempoCapMs: 500,
  );

  static const strict = RefereeConfig(
    minVisibility: 0.3,
    landmarkLostGraceFrames: 15,
    landmarkLostFeedbackFrames: 30,
    postureWristOverheadFraction: 0.15,
    pushupMinHandDepthFraction: 0.42,
    pushupMaxTorsoVerticality: 0.65,
    postureInvalidGraceFrames: 5,
    goodDepthAngle: 85.0,
    alignmentMaxDeviation: 0.14,
    incompleteDropFromUp: 25.0,
    elbowUpAngle: 160.0,
    elbowDownAngle: 95.0,
    angleSmoothing: 0.7,
    tempoCapMs: 700,
  );
}
