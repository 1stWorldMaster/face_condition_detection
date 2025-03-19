import 'dart:io';
import 'dart:ui'; // Added this import for Rect
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class FaceProcessor {
  final FaceDetector _faceDetector = GoogleMlKit.vision.faceDetector();

  Future<List<Rect>> detectFaces(XFile picture) async {
    final File imageFile = File(picture.path);
    final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
    final List<Face> faces = await _faceDetector.processImage(inputImage);

    return faces
        .where((face) => face.boundingBox.width > 100)
        .map((face) => face.boundingBox)
        .toList();
  }

  void dispose() {
    _faceDetector.close();
  }
}