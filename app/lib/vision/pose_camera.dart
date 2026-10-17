import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'pose_service.dart';

/// Full-bleed camera preview with ML Kit pose detection.
/// Calls [onResult] for every processed frame (null when no pose is found).
class PoseCamera extends StatefulWidget {
  const PoseCamera({super.key, required this.onResult});

  final ValueChanged<PoseResult?> onResult;

  @override
  State<PoseCamera> createState() => _PoseCameraState();
}

class _PoseCameraState extends State<PoseCamera> with WidgetsBindingObserver {
  final PoseService _poseService = PoseService();
  CameraController? _controller;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _error = 'No camera found on this device.');
        }
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.startImageStream(_onFrame);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Camera error: $error');
      }
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final controller = _controller;
    if (controller == null || _busy) {
      return;
    }
    _busy = true;
    try {
      final input = _poseService.inputImageFromCamera(image, controller);
      PoseResult? result;
      if (input != null) {
        result = await _poseService.detect(input);
      }
      if (mounted) {
        widget.onResult(result);
      }
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller = null;
      controller.dispose();
      setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _poseService.close();
    super.dispose();
  }

  Widget _preview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const ColoredBox(color: Colors.black);
    }
    final screenWidth = MediaQuery.sizeOf(context).width;
    final uprightAspect = previewSize.width > previewSize.height
        ? previewSize.height / previewSize.width
        : previewSize.width / previewSize.height;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: screenWidth,
          height: screenWidth / uprightAspect,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      return _preview(controller);
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
