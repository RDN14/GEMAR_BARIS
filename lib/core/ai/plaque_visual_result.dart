import 'dart:typed_data';

class PlaqueVisualResult {
  final double plaqueRatio;
  final int score;
  final String label;
  final Uint8List? overlayPngBytes;

  const PlaqueVisualResult({
    required this.plaqueRatio,
    required this.score,
    required this.label,
    required this.overlayPngBytes,
  });
}