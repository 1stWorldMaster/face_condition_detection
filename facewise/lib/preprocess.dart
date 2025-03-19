import 'dart:typed_data';  // Added this import for Uint8List
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'dart:async';
import 'dart:ui';

class FaceProcessor {
  final FaceDetector _faceDetector = GoogleMlKit.vision.faceDetector(
    FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  List<Rect> faceCoordinates = [];
  final Function(List<Rect>) onFacesDetected;
  bool _isProcessing = false;

  FaceProcessor({required this.onFacesDetected});

  Future<void> processCameraImage(CameraImage image, CameraDescription camera) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final InputImage inputImage = _convertCameraImage(image, camera);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      faceCoordinates = faces
          .where((face) => face.boundingBox.width > 100)
          .map((face) => face.boundingBox)
          .toList();

      onFacesDetected(faceCoordinates);
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isProcessing = false;
    }
  }

  InputImage _convertCameraImage(CameraImage image, CameraDescription camera) {
    // For Android NV21 format, we need to concatenate all planes
    final allBytes = <int>[];
    for (final plane in image.planes) {
      allBytes.addAll(plane.bytes);
    }

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: _rotationForCamera(camera),
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: Uint8List.fromList(allBytes),
      metadata: metadata,
    );
  }

  InputImageRotation _rotationForCamera(CameraDescription camera) {
    // Adjust rotation based on camera sensor orientation and lens direction
    var rotation = camera.sensorOrientation;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotation = (360 - rotation) % 360;
    }

    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}