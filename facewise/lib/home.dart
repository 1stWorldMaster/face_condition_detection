import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera.dart';

class FaceDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const FaceDetectionScreen({super.key, required this.cameras});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  late final CameraLogic _cameraLogic;

  @override
  void initState() {
    super.initState();
    _cameraLogic = CameraLogic(widget.cameras, _updateState);
    _cameraLogic.initialize();
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cameraLogic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraLogic.isCameraInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_cameraLogic.controller),
          Positioned(
            bottom: 20,
            left: 20,
            child: ValueListenableBuilder<String>(
              valueListenable: _cameraLogic.status,
              builder: (context, status, child) => Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: Text(
                  status,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 20,
            child: ValueListenableBuilder<double>(
              valueListenable: _cameraLogic.currentBrightness,
              builder: (context, brightness, child) => ValueListenableBuilder<double>(
                valueListenable: _cameraLogic.exposureOffset,
                builder: (context, exposure, child) => Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black54,
                  child: Text(
                    "Brightness: ${brightness.toStringAsFixed(2)} | Exposure: ${exposure.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: FloatingActionButton(
              onPressed: _cameraLogic.switchCamera,
              child: const Icon(Icons.flip_camera_android),
            ),
          ),
        ],
      ),
    );
  }
}