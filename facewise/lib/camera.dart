import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'preprocess.dart';

class FaceDetectionScreen extends StatefulWidget {
  const FaceDetectionScreen({super.key});

  @override
  _FaceDetectionScreenState createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  late CameraController _controller;
  late FaceProcessor _faceProcessor;
  int currentCameraIndex = 1; // 0 for back camera, 1 for front camera typically

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceProcessor = FaceProcessor(
      onFacesDetected: (faces) {
        setState(() {});
      },
    );
  }

  void _initializeCamera() {
    _controller = CameraController(
      cameras[currentCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _controller.initialize().then((_) {
      if (!mounted) return;
      _startRealTimeDetection();
      setState(() {});
    }).catchError((e) {
      print('Error initializing camera: $e');
    });
  }

  void _startRealTimeDetection() {
    _controller.startImageStream((CameraImage image) {
      _faceProcessor.processCameraImage(image, _controller.description);
    });
  }

  Future<void> _switchCamera() async {
    if (cameras.length < 2) return;

    setState(() {
      currentCameraIndex = (currentCameraIndex + 1) % cameras.length;
    });

    await _controller.dispose();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller.stopImageStream();
    _controller.dispose();
    _faceProcessor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_controller),
          CustomPaint(
            painter: FacePainter(_faceProcessor.faceCoordinates),
            child: Container(),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _switchCamera,
              child: const Icon(Icons.flip_camera_android),
            ),
          ),
        ],
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Rect> faceCoordinates;

  FacePainter(this.faceCoordinates);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var rect in faceCoordinates) {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}