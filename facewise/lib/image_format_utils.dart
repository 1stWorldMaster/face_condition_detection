import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class ImageFormatUtils {
  static Uint8List convertToBytes(CameraImage image, {required InputImageFormat outputFormat}) {
    final formatGroup = image.format.group;
    Uint8List bytes;

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
        return bytes;

      case ImageFormatGroup.nv21:
        bytes = image.planes[0].bytes;
        return bytes;

      default:
        throw Exception("Unsupported image format: $formatGroup");
    }
  }

  static InputImageFormat getInputImageFormat(ImageFormatGroup formatGroup) {
    switch (formatGroup) {
      case ImageFormatGroup.yuv420:
        return InputImageFormat.yuv_420_888;
      case ImageFormatGroup.nv21:
        return InputImageFormat.nv21;
      default:
        throw Exception("Unsupported image format: $formatGroup");
    }
  }
}