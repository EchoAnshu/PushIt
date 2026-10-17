import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../engine/models.dart' as engine;

const _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

class PoseResult {
  final List<engine.Landmark> landmarks;
  final double width;
  final double height;

  const PoseResult(this.landmarks, this.width, this.height);
}

class PoseService {
  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    ),
  );

  InputImage? inputImageFromCamera(
    CameraImage image,
    CameraController controller,
  ) {
    final rotationCompensation =
        _orientations[controller.value.deviceOrientation] ?? 0;
    final sensorOrientation = controller.description.sensorOrientation;
    final int degrees;
    if (controller.description.lensDirection == CameraLensDirection.front) {
      degrees = (sensorOrientation + rotationCompensation) % 360;
    } else {
      degrees = (sensorOrientation - rotationCompensation + 360) % 360;
    }
    final rotation = InputImageRotationValue.fromRawValue(degrees);
    if (rotation == null) {
      return null;
    }
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || format != InputImageFormat.nv21) {
      return null;
    }
    if (image.planes.isEmpty) {
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<PoseResult?> detect(InputImage inputImage) async {
    final poses = await _detector.processImage(inputImage);
    if (poses.isEmpty) {
      return null;
    }
    final pose = poses.first;

    final metadata = inputImage.metadata!;
    var width = metadata.size.width;
    var height = metadata.size.height;
    if (metadata.rotation == InputImageRotation.rotation90deg ||
        metadata.rotation == InputImageRotation.rotation270deg) {
      final swap = width;
      width = height;
      height = swap;
    }

    final landmarks = List<engine.Landmark>.generate(
      engine.landmarkCount,
      (_) => const engine.Landmark(0.5, 0.5, 0.0),
    );
    pose.landmarks.forEach((type, landmark) {
      final index = type.index;
      if (index < 0 || index >= engine.landmarkCount) {
        return;
      }
      landmarks[index] = engine.Landmark(
        landmark.x / width,
        landmark.y / height,
        landmark.likelihood,
      );
    });

    return PoseResult(landmarks, width, height);
  }

  void close() {
    _detector.close();
  }
}
