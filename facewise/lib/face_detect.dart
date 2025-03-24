import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FaceProcessor {
  static Future<Uint8List?> processFace({
    required CameraImage cameraImage,
    required Face face,
  }) async {
    try {
      // Step 1: Convert CameraImage to img.Image (in color initially)
      img.Image originalImage = _convertCameraImageToImage(cameraImage);

      // Step 2: Crop the detected face
      final boundingBox = face.boundingBox;

      // Extract coordinates and ensure they fit within image bounds
      int x = boundingBox.left.toInt().clamp(0, originalImage.width);
      int y = boundingBox.top.toInt().clamp(0, originalImage.height);
      int width = boundingBox.width.toInt().clamp(0, originalImage.width - x);
      int height = boundingBox.height.toInt().clamp(0, originalImage.height - y);

      final croppedFace = img.copyCrop(
        originalImage,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      // Step 3: Resize to 48x48
      final resizedFace = img.copyResize(
        croppedFace,
        width: 48,
        height: 48,
        interpolation: img.Interpolation.nearest,
      );

      // Step 4: Convert to grayscale (black and white)
      final grayscaleFace = img.grayscale(resizedFace);

      // Step 5: Convert to Uint8List (JPEG bytes)
      final imageBytes = Uint8List.fromList(img.encodeJpg(grayscaleFace));

      return imageBytes;
    } catch (e) {
      print("Error processing face: $e");
      return null;
    }
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

        // YUV to RGB conversion (for intermediate processing)
        final int r = (Y + 1.402 * V).round().clamp(0, 255);
        final int g = (Y - 0.344 * U - 0.714 * V).round().clamp(0, 255);
        final int b = (Y + 1.772 * U).round().clamp(0, 255);

        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }
}