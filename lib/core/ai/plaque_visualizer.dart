import 'dart:typed_data';
import 'package:image/image.dart' as img;

class PlaqueVisualizer {
  /// Versi awal:
  /// pakai plaque ratio untuk mewarnai area tengah gigi secara sederhana.
  /// Ini BELUM mask YOLO asli, tapi cukup untuk bukti visual awal.
  static Uint8List? buildSimpleOverlay({
    required Uint8List originalBytes,
    required double plaqueRatio,
  }) {
    final original = img.decodeImage(originalBytes);
    if (original == null) return null;

    final canvas = img.copyResize(
      original,
      width: original.width,
      height: original.height,
    );

    if (plaqueRatio <= 0.01) {
      return Uint8List.fromList(img.encodePng(canvas));
    }

    final width = canvas.width;
    final height = canvas.height;

    final left = (width * 0.18).toInt();
    final right = (width * 0.82).toInt();
    final top = (height * 0.22).toInt();
    final bottom = (height * 0.78).toInt();

    final intensity = (plaqueRatio.clamp(0.0, 1.0) * 180).toInt();

    for (int y = top; y < bottom; y++) {
      for (int x = left; x < right; x++) {
        final p = canvas.getPixel(x, y);

        // overlay kuning-oranye transparan
        final r = (p.r + intensity).clamp(0, 255).toInt();
        final g = (p.g + (intensity * 0.8)).clamp(0, 255).toInt();
        final b = (p.b * 0.75).clamp(0, 255).toInt();

        canvas.setPixelRgb(x, y, r, g, b);
      }
    }

    return Uint8List.fromList(img.encodePng(canvas));
  }
}