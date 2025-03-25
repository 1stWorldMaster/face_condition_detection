import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:facewise/face_detect.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:math' as math;

class FaceDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const FaceDetectionScreen({super.key, required this.cameras});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  late CameraController _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );
  final ValueNotifier<String> _status = ValueNotifier('Initializing...');
  final ValueNotifier<List<double>?> _processedFace = ValueNotifier(null);
  final ValueNotifier<double> _currentBrightness = ValueNotifier(0.0);
  final ValueNotifier<double> _exposureOffset = ValueNotifier(0.0);
  int _currentCameraIndex = 0;
  bool _isProcessing = false;
  DateTime? _lastProcessed;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;

  final List<String> emotions = ["Angry", "Disgust", "Fear", "Happy", "Sad", "Surprise", "Neutral"];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      _status.value = 'No cameras available';
      setState(() => _isCameraInitialized = false);
      return;
    }

    _controller = CameraController(
      widget.cameras[_currentCameraIndex],
      ResolutionPreset.low,
      enableAudio: false,
    );

    try {
      await _controller.initialize();
      await _controller.startImageStream(_processImage);
      setState(() {
        _isCameraInitialized = true;
        _status.value = 'Detecting...';
      });
    } catch (e) {
      setState(() {
        _isCameraInitialized = false;
        _status.value = 'Error initializing camera: $e';
      });
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

      final formatGroup = image.format.group;
      Uint8List bytes;
      InputImageFormat format;

      switch (formatGroup) {
        case ImageFormatGroup.yuv420:
          final yPlane = image.planes[0].bytes;
          final uPlane = image.planes[1].bytes;
          final vPlane = image.planes[2].bytes;
          final totalSize = yPlane.length + uPlane.length + vPlane.length;
          bytes = Uint8List(totalSize)
            ..setRange(0, yPlane.length, yPlane)
            ..setRange(yPlane.length, yPlane.length + uPlane.length, uPlane)
            ..setRange(yPlane.length + uPlane.length, totalSize, vPlane);
          format = InputImageFormat.yuv_420_888;
          break;

        case ImageFormatGroup.nv21:
          bytes = image.planes[0].bytes;
          format = InputImageFormat.nv21;
          break;

        default:
          throw Exception("Unsupported image format: $formatGroup");
      }

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: _getRotationForCamera(widget.cameras[_currentCameraIndex]),
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final faceBytes = await FaceProcessor.processFace(
          cameraImage: image,
          face: faces[0],
          sensorOrientation: widget.cameras[_currentCameraIndex].sensorOrientation,
        );

        _processedFace.value = faceBytes;

        if (faceBytes != null && faceBytes.length == emotions.length) {
          final maxProbIndex = faceBytes.indexOf(faceBytes.reduce(math.max));
          _status.value = "${emotions[maxProbIndex]} (${(faceBytes[maxProbIndex] * 100).toStringAsFixed(1)}%)";
        } else {
          _status.value = "Face detected";
        }
      } else {
        _status.value = "Face not detected";
      }
    } catch (e) {
      _status.value = "Error: $e";
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

    _currentBrightness.value = totalLuminance / pixelCount / 255;
  }

  Future<void> _adjustExposureAutomatically() async {
    try {
      const double tooBrightThreshold = 0.6;
      const double tooDimThreshold = 0.3;
      const double step = 0.5; // Increased step size for more noticeable exposure adjustment

      final minExposure = await _controller.getMinExposureOffset();
      final maxExposure = await _controller.getMaxExposureOffset();
      double newExposureOffset = _exposureOffset.value;

      // Handle brightness too high
      if (_currentBrightness.value > tooBrightThreshold) {
        newExposureOffset = math.max(minExposure, _exposureOffset.value - step);
        if (_isFlashOn) {
          await _controller.setFlashMode(FlashMode.off);
          _isFlashOn = false;
        }
      }
      // Handle brightness too low
      else if (_currentBrightness.value < tooDimThreshold && _currentCameraIndex == 0) {
        newExposureOffset = math.min(maxExposure, _exposureOffset.value + step);
        if (!_isFlashOn) {
          await _controller.setFlashMode(FlashMode.torch);
          _isFlashOn = true;
        }
      }
      // Handle normal brightness range
      else if (_isFlashOn) {
        await _controller.setFlashMode(FlashMode.off);
        _isFlashOn = false;
      }

      // Apply exposure change if needed
      if (newExposureOffset != _exposureOffset.value) {
        await _controller.setExposureOffset(newExposureOffset);
        _exposureOffset.value = newExposureOffset;
      }
    } catch (e) {
      _status.value = "Exposure/Flash error: $e"; // Temporary for debugging
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

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) {
      _status.value = 'Only one camera available';
      return;
    }

    await _controller.stopImageStream();
    _currentCameraIndex = (_currentCameraIndex + 1) % widget.cameras.length;
    await _controller.setDescription(widget.cameras[_currentCameraIndex]);
    if (_isFlashOn) {
      await _controller.setFlashMode(FlashMode.off);
      _isFlashOn = false;
    }
    await _controller.startImageStream(_processImage);
  }

  @override
  void dispose() {
    _controller.stopImageStream();
    _controller.dispose();
    _faceDetector.close();
    _status.dispose();
    _processedFace.dispose();
    _currentBrightness.dispose();
    _exposureOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_controller),
          Positioned(
            bottom: 20,
            left: 20,
            child: ValueListenableBuilder<String>(
              valueListenable: _status,
              builder: (context, status, child) => Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 20,
            child: ValueListenableBuilder<double>(
              valueListenable: _currentBrightness,
              builder: (context, brightness, child) => ValueListenableBuilder<double>(
                valueListenable: _exposureOffset,
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
              onPressed: _switchCamera,
              child: const Icon(Icons.flip_camera_android),
            ),
          ),
        ],
      ),
    );
  }
}