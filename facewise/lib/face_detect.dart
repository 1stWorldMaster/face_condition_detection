import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceProcessor {
  static Interpreter? _interpreter;

  // Load the TFLite model when the class is first used
  static Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('model.tflite');
      print("Model loaded successfully");
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  static Future<Uint8List?> processFace({
    required CameraImage cameraImage,
    required Face face,
    required int sensorOrientation, // Camera sensor orientation (e.g., 90, 180, 270)
  }) async {
    try {
      // Load the model if not already loaded
      if (_interpreter == null) {
        await _loadModel();
      }

      // Step 1: Convert CameraImage to img.Image (in color initially)
      img.Image originalImage = _convertCameraImageToImage(cameraImage);

      // Step 2: Adjust for orientation using only sensor orientation
      final adjustedImage = _adjustImageOrientation(
        originalImage,
        sensorOrientation,
      );

      // Step 3: Crop the detected face
      final boundingBox = face.boundingBox;

      // Extract coordinates and ensure they fit within image bounds
      int x = boundingBox.left.toInt().clamp(0, adjustedImage.width);
      int y = boundingBox.top.toInt().clamp(0, adjustedImage.height);
      int width = boundingBox.width.toInt().clamp(0, adjustedImage.width - x);
      int height = boundingBox.height.toInt().clamp(0, adjustedImage.height - y);

      final croppedFace = img.copyCrop(
        adjustedImage,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      // Step 4: Resize to 48x48
      final resizedFace = img.copyResize(
        croppedFace,
        width: 48,
        height: 48,
        interpolation: img.Interpolation.nearest,
      );

      // Step 5: Convert to grayscale (black and white)
      final grayscaleFace = img.grayscale(resizedFace);

      // Step 6: Prepare input for the model (1, 48, 48, 1)
      final input = _prepareInputForModel(grayscaleFace);

      // Step 7: Run the model and get the output
      final output = _runModel(input);

      // Step 8: Print the model output (assuming integer output)
      print("Model output: $output");

      // Step 9: Convert to Uint8List (JPEG bytes) for return (if needed)
      final imageBytes = Uint8List.fromList(img.encodeJpg(grayscaleFace));

      return imageBytes;
    } catch (e) {
      print("Error processing face: $e");
      return null;
    }
  }

  static List<List<List<List<double>>>> _prepareInputForModel(img.Image grayscaleFace) {
    // Convert the grayscale image to a 1x48x48x1 tensor
    final input = List.generate(
      1,
          (_) => List.generate(
        48,
            (y) => List.generate(
          48,
              (x) => [grayscaleFace.getPixel(x, y).r / 255.0], // Normalize to [0, 1]
        ),
      ),
    );
    return input;
  }

  static int _runModel(List<List<List<List<double>>>> input) {
    if (_interpreter == null) {
      print("Model not loaded");
      return -1; // Default error value
    }

    // Define the output tensor shape (adjust based on your model's output)
    // Assuming the model outputs a single integer (e.g., classification)
    var output = List.filled(1, 0); // Modify based on actual output shape

    // Run inference
    _interpreter!.run(input, output);

    // Return the first integer value from the output
    return output[0];
  }

  static img.Image _convertCameraImageToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final yPlane = cameraImage.planes[0].bytes;
    final uPlane = cameraImage.planes[1].bytes;
    final vPlane = cameraImage.planes[2].bytes;

    final image = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);
        final int yIndex = y * width + x;

        final int Y = yPlane[yIndex];
        final int U = uPlane[uvIndex] - 128;
        final int V = vPlane[uvIndex] - 128;

        // YUV to RGB conversion
        final int r = (Y + 1.402 * V).round().clamp(0, 255);
        final int g = (Y - 0.344 * U - 0.714 * V).round().clamp(0, 255);
        final int b = (Y + 1.772 * U).round().clamp(0, 255);

        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }

  static img.Image _adjustImageOrientation(
      img.Image image,
      int sensorOrientation,
      ) {
    // Use sensor orientation directly as the rotation angle
    switch (sensorOrientation) {
      case 90:
        return img.copyRotate(image, angle: 90);
      case 180:
        return img.copyRotate(image, angle: 180);
      case 270:
        return img.copyRotate(image, angle: 270);
      case 0:
      default:
        return image; // No rotation needed
    }
  }
}