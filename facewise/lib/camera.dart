import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:facewise/face_detect.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:math' as math;
import 'image_format_utils.dart';


class CameraLogic {
  final List<CameraDescription> cameras;
  late CameraController controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );
  final ValueNotifier<String> status = ValueNotifier('Initializing...');
  final ValueNotifier<List<double>?> processedFace = ValueNotifier(null);
  final ValueNotifier<double> currentBrightness = ValueNotifier(0.0);
  final ValueNotifier<double> exposureOffset = ValueNotifier(0.0);
  int _currentCameraIndex = 0;
  bool _isProcessing = false;
  DateTime? _lastProcessed;
  bool isCameraInitialized = false;
  bool _isFlashOn = false;
  final VoidCallback updateState;
  final List<String> emotions = ["Angry", "Disgust", "Fear", "Happy", "Sad", "Surprise", "Neutral"];

  CameraLogic(this.cameras, this.updateState);

  Future<void> initialize() async {
    if (cameras.isEmpty) {
      status.value = 'No cameras available';
      isCameraInitialized = false;
      updateState();
      return;
    }

    controller = CameraController(
      cameras[_currentCameraIndex],
      ResolutionPreset.low,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      await controller.startImageStream(_processImage);
      isCameraInitialized = true;
      status.value = 'Detecting...';
      updateState();
    } catch (e) {
      isCameraInitialized = false;
      status.value = 'Error initializing camera: $e';
      updateState();
    }
  }

  void _processImage(CameraImage image) async {
    final now = DateTime.now();
    if (_lastProcessed != null && now.difference(_lastProcessed!).inMilliseconds < 200) return;
    if (_isProcessing) return;

    _isProcessing = true;
    _lastProcessed = now;

    try {
      _analyzeBrightness(image);
      await _adjustExposureAutomatically();

      final bytes = ImageFormatUtils.convertToBytes(image, outputFormat: ImageFormatUtils.getInputImageFormat(image.format.group));
      final format = ImageFormatUtils.getInputImageFormat(image.format.group);

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: _getRotationForCamera(cameras[_currentCameraIndex]),
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final faceBytes = await FaceProcessor.processFace(
          cameraImage: image,
          face: faces[0],
          sensorOrientation: cameras[_currentCameraIndex].sensorOrientation,
        );

        processedFace.value = faceBytes;

        if (faceBytes != null && faceBytes.length == emotions.length) {
          final maxProbIndex = faceBytes.indexOf(faceBytes.reduce(math.max));
          status.value = "${emotions[maxProbIndex]} (${(faceBytes[maxProbIndex] * 100).toStringAsFixed(1)}%)";
        } else {
          status.value = "Face detected";
        }
      } else {
        status.value = "Face not detected";
      }
    } catch (e) {
      status.value = "Error: $e";
    } finally {
      _isProcessing = false;
    }
  }

  void _analyzeBrightness(CameraImage image) {
    final yBuffer = image.planes[0].bytes;
    final pixelCount = image.width * image.height;
    double totalLuminance = 0;

    for (int i = 0; i < pixelCount; i++) {
      totalLuminance += yBuffer[i];
    }

    currentBrightness.value = totalLuminance / pixelCount / 255;
  }

  Future<void> _adjustExposureAutomatically() async {
    try {
      const double tooBrightThreshold = 0.6;
      const double tooDimThreshold = 0.3;
      const double step = 0.5;

      final minExposure = await controller.getMinExposureOffset();
      final maxExposure = await controller.getMaxExposureOffset();
      double newExposureOffset = exposureOffset.value;

      if (currentBrightness.value > tooBrightThreshold) {
        newExposureOffset = math.max(minExposure, exposureOffset.value - step);
        if (_isFlashOn) {
          await controller.setFlashMode(FlashMode.off);
          _isFlashOn = false;
        }
      } else if (currentBrightness.value < tooDimThreshold && _currentCameraIndex == 0) {
        newExposureOffset = math.min(maxExposure, exposureOffset.value + step);
        if (!_isFlashOn) {
          await controller.setFlashMode(FlashMode.torch);
          _isFlashOn = true;
        }
      } else if (_isFlashOn) {
        await controller.setFlashMode(FlashMode.off);
        _isFlashOn = false;
      }

      if (newExposureOffset != exposureOffset.value) {
        await controller.setExposureOffset(newExposureOffset);
        exposureOffset.value = newExposureOffset;
      }
    } catch (e) {
      status.value = "Exposure/Flash error: $e";
    }
  }

  InputImageRotation _getRotationForCamera(CameraDescription camera) {
    switch (camera.sensorOrientation) {
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

  // Function to switch the camera
  Future<void> switchCamera() async {
    if (cameras.length < 2) {
      status.value = 'Only one camera available';
      return;
    }

    await controller.stopImageStream();
    _currentCameraIndex = (_currentCameraIndex + 1) % cameras.length;
    await controller.setDescription(cameras[_currentCameraIndex]);
    if (_isFlashOn) {
      await controller.setFlashMode(FlashMode.off);
      _isFlashOn = false;
    }
    await controller.startImageStream(_processImage);
  }

// Dispose function
  void dispose() {
    controller.stopImageStream();
    controller.dispose();
    _faceDetector.close();
    status.dispose();
    processedFace.dispose();
    currentBrightness.dispose();
    exposureOffset.dispose();
  }
}