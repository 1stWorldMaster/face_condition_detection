import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'preprocess.dart';
import 'main.dart';
import 'dart:ui';

class FaceDetectionScreen extends StatefulWidget {
  @override
  _FaceDetectionScreenState createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  late CameraController _controller;
  List<Rect> faceCoordinates = [];
  bool isDetecting = false;
  int currentCameraIndex = 1; // 0 for back camera, 1 for front camera typically
  final FaceProcessor _faceProcessor = FaceProcessor();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() {
    _controller = CameraController(
      cameras[currentCameraIndex],
      ResolutionPreset.medium,
    );
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      // Start the image stream for continuous detection
      _controller.startImageStream(_processCameraImage);
    }).catchError((e) {
      print('Error initializing camera: $e');
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

  void _processCameraImage(CameraImage image) async {
    if (isDetecting || !mounted) return;

    setState(() => isDetecting = true);

    final List<Rect> detectedFaces = await _faceProcessor.detectFacesFromStream(image, _controller.description);

    if (mounted) {
      setState(() {
        faceCoordinates = detectedFaces;
        isDetecting = false;
      });
    }
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
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_controller),
          CustomPaint(
            painter: FacePainter(faceCoordinates),
            child: Container(),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _switchCamera,
              child: Icon(Icons.flip_camera_android),
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