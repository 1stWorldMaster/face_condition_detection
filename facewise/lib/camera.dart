import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'preprocess.dart';
import 'main.dart';

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

  Future<void> _detectFaces() async {
    if (isDetecting || !_controller.value.isInitialized) return;

    setState(() => isDetecting = true);

    final XFile picture = await _controller.takePicture();
    final List<Rect> detectedFaces = await _faceProcessor.detectFaces(picture);

    setState(() {
      faceCoordinates = detectedFaces;
      isDetecting = false;
    });
  }

  @override
  void dispose() {
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
            bottom: 20,
            left: MediaQuery.of(context).size.width / 2 - 50,
            child: ElevatedButton(
              onPressed: _detectFaces,
              child: Text(isDetecting ? 'Detecting...' : 'Detect Faces'),
            ),
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