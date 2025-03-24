import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:facewise/face_detect.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FaceDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const FaceDetectionScreen({super.key, required this.cameras});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  late CameraController _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      enableContours: false,
      enableLandmarks: false,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  String _status = 'Initializing...';
  int _currentCameraIndex = 0; // 0 for front, 1 for back (if available)
  Uint8List? _processedFace;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() => _status = 'No cameras available');
      return;
    }
    _controller = CameraController(
      widget.cameras[_currentCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller.initialize();
    _controller.startImageStream(_processImage);
    setState(() {
      // _status = 'Detecting...';
    });
  }

  int _frameCounter = 0;
  void _processImage(CameraImage image) async {
    _frameCounter++;
    if (_frameCounter % 3 != 0) return;

    final formatGroup = image.format.group;
    Uint8List bytes;
    InputImageFormat format;

    switch (formatGroup) {
      case ImageFormatGroup.yuv420: // YUV_420_888 on Android
        if (image.planes.length < 3) {
          throw Exception("YUV420 image must have 3 planes (Y, U, V)");
        }
        // Combine Y, U, and V planes into a single ByteBuffer
        final yPlane = image.planes[0].bytes;
        final uPlane = image.planes[1].bytes;
        final vPlane = image.planes[2].bytes;

        final totalSize = yPlane.length + uPlane.length + vPlane.length;
        bytes = Uint8List(totalSize);

        // Copy Y plane
        bytes.setRange(0, yPlane.length, yPlane);
        // Copy U plane
        bytes.setRange(yPlane.length, yPlane.length + uPlane.length, uPlane);
        // Copy V plane
        bytes.setRange(yPlane.length + uPlane.length, totalSize, vPlane);

        format = InputImageFormat.yuv_420_888;
        break;

      case ImageFormatGroup.nv21: // NV21 on some Android devices
      // NV21 is already a single contiguous buffer
        bytes = image.planes[0].bytes;
        format = InputImageFormat.nv21; // NV21 is supported
        break;

      default:
        throw Exception("Unsupported image format: $formatGroup");
    }

    // Create InputImage with the appropriate format
    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    _frameCounter = 0;

    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isNotEmpty) {
      final faceBytes = await FaceProcessor.processFace(
        cameraImage: image,
        face: faces[0],
      );

      setState(() {
        _status = "face detected";
        if (faceBytes != null) {
          _processedFace = faceBytes;
        }
      });
      print("face detected");

      final result = await FaceProcessor.processFace(
        cameraImage: image,
        face: faces[0],
      );
    } else {
      setState(() {
        _status = "face not detected";
      });
    }
  }

  InputImageRotation _getRotationForCamera(CameraDescription camera) {
    // Adjust rotation based on camera sensor orientation
    if (camera.lensDirection == CameraLensDirection.front) {
      return InputImageRotation.rotation270deg; // Front camera often needs this
    } else {
      return InputImageRotation.rotation90deg; // Back camera
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) {
      setState(() => _status = 'Only one camera available');
      return;
    }

    // Stop the current stream and dispose of the controller
    await _controller.stopImageStream();
    await _controller.dispose();

    // Toggle camera index
    _currentCameraIndex = (_currentCameraIndex + 1) % widget.cameras.length;

    // Reinitialize with the new camera
    await _initializeCamera();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
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
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                _status,
                style: const TextStyle(color: Colors.white, fontSize: 18),
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
          if (_processedFace != null)
            Positioned(
              // Added Positioned widget to place the image properly in the Stack
              top: 40,
              left: 20,
              child: Image.memory(_processedFace!, width: 48, height: 48),
            ),
        ],
      ),
    );
  }
}
