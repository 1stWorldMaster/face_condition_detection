import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:facewise/camera.dart';
import 'package:facewise/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(FaceDetectionApp(cameras: cameras));
}

class FaceDetectionApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const FaceDetectionApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Detection with Camera Switch',
      home: FaceDetectionScreen(cameras: cameras), // Ensure this class exists
    );
  }
}