import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceProcessor {
  static Interpreter? _interpreter; // Singleton interpreter to reuse
  static Float32List? _inputBuffer; // Reusable input buffer

  static Future<void> initializeInterpreter() async {
    if (_interpreter == null) {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      _inputBuffer = Float32List(1 * 48 * 48 * 1); // Pre-allocate input buffer
    }
  }

  static Future<List<double>?> processFace({
    required CameraImage cameraImage,
    required Face face,
    required int sensorOrientation,
  }) async {
    await initializeInterpreter(); // Ensure interpreter is ready
    final interpreter = _interpreter;
    if (interpreter == null || _inputBuffer == null) {
      print("Interpreter not initialized");
      return null;
    }

    try {
      // Step 1: Convert CameraImage to img.Image efficiently
      img.Image originalImage = _convertCameraImageToImage(cameraImage);

      // Step 2: Adjust orientation
      final adjustedImage = _adjustImageOrientation(
          originalImage, sensorOrientation);

      // Step 3: Crop the detected face
      final boundingBox = face.boundingBox;
      int x = boundingBox.left.toInt().clamp(0, adjustedImage.width);
      int y = boundingBox.top.toInt().clamp(0, adjustedImage.height);
      int width = boundingBox.width.toInt().clamp(0, adjustedImage.width - x);
      int height = boundingBox.height.toInt().clamp(
          0, adjustedImage.height - y);

      final croppedFace = img.copyCrop(
        adjustedImage,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      // Step 4: Resize to 48x48 and convert to grayscale in one step
      final resizedFace = img.copyResize(
        croppedFace,
        width: 48,
        height: 48,
        interpolation: img.Interpolation.nearest,
      );
      final grayscaleFace = img.grayscale(resizedFace);

      // Step 5: Prepare input using pre-allocated buffer
      int pixelIndex = 0;
      for (int i = 0; i < 48; i++) {
        for (int j = 0; j < 48; j++) {
          final pixel = grayscaleFace.getPixel(j, i);
          _inputBuffer![pixelIndex++] = pixel.r / 255.0;
        }
      }
      final reshapedInput = _inputBuffer!.reshape([1, 48, 48, 1]);

      // Step 6: Run inference
      final output = List.filled(1 * 7, 0.0).reshape([1, 7]);
      interpreter.run(reshapedInput, output);

      // Step 7: Return inference result
      return output[0];
    } catch (e) {
      print("Error processing face: $e");
      return null;
    }
  }

  static img.Image _convertCameraImageToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final image = img.Image(width: width, height: height);

    final yPlane = cameraImage.planes[0].bytes;
    final uPlane = cameraImage.planes[1].bytes;
    final vPlane = cameraImage.planes[2].bytes;

    // Pre-calculate strides to reduce redundant calculations
    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;
        final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final int Y = yPlane[yIndex];
        final int U = uPlane[uvIndex] - 128;
        final int V = vPlane[uvIndex] - 128;

        final int r = (Y + 1.402 * V).round().clamp(0, 255);
        final int g = (Y - 0.344 * U - 0.714 * V).round().clamp(0, 255);
        final int b = (Y + 1.772 * U).round().clamp(0, 255);

        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }

  static img.Image _adjustImageOrientation(img.Image image,
      int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return img.copyRotate(image, angle: 90);
      case 180:
        return img.copyRotate(image, angle: 180);
      case 270:
        return img.copyRotate(image, angle: 270);
      case 0:
      default:
        return image;
    }
  }
}