import 'dart:io';
import 'package:image/image.dart' as img;

class PlaqueResult {
  const PlaqueResult({
    required this.score,
    required this.yellowRatio,
    required this.yellowCount,
    required this.sampleCount,
  });

  final int score; // 1..5
  final double yellowRatio; // 0..1
  final int yellowCount;
  final int sampleCount;
}

class HSVPlaqueAnalyzer {
  static Future<PlaqueResult> analyze(
    File file, {
    int maxWidth = 512,
    int step = 4,
    // Threshold bisa kamu tuning nanti
    double darkV = 0.25,
    double whiteMaxS = 0.15,
    double whiteMinV = 0.80,
    double yellowMinH = 20,
    double yellowMaxH = 55,
    double yellowMinS = 0.20,
    double yellowMinV = 0.25,
  }) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Gagal decode image');

    final resized = img.copyResize(
      decoded,
      width: decoded.width > maxWidth ? maxWidth : decoded.width,
    );

    int yellowCount = 0;
    int sampleCount = 0;

    for (int y = 0; y < resized.height; y += step) {
      for (int x = 0; x < resized.width; x += step) {
        final p = resized.getPixel(x, y);
        final hsv = _rgbToHsv(p.r.toInt(), p.g.toInt(), p.b.toInt());

        final isDark = hsv.v < darkV;
        final isWhite = (hsv.s <= whiteMaxS && hsv.v >= whiteMinV);

        // buang gelap & putih/refleksi
        if (isDark || isWhite) continue;

        sampleCount++;

        final isYellow = (hsv.h >= yellowMinH &&
            hsv.h <= yellowMaxH &&
            hsv.s >= yellowMinS &&
            hsv.v >= yellowMinV);

        if (isYellow) yellowCount++;
      }
    }

    final ratio = sampleCount == 0 ? 0.0 : yellowCount / sampleCount;
    final score = _ratioToScore(ratio);

    return PlaqueResult(
      score: score,
      yellowRatio: ratio,
      yellowCount: yellowCount,
      sampleCount: sampleCount,
    );
  }

  static int _ratioToScore(double ratio) {
    if (ratio < 0.05) return 1;
    if (ratio < 0.15) return 2;
    if (ratio < 0.30) return 3;
    if (ratio < 0.50) return 4;
    return 5;
  }

  static _Hsv _rgbToHsv(int r, int g, int b) {
    final rf = r / 255.0;
    final gf = g / 255.0;
    final bf = b / 255.0;

    final maxc = _max3(rf, gf, bf);
    final minc = _min3(rf, gf, bf);
    final delta = maxc - minc;

    final v = maxc;
    final s = maxc == 0.0 ? 0.0 : delta / maxc;

    double h;
    if (delta == 0.0) {
      h = 0.0;
    } else if (maxc == rf) {
      h = 60.0 * (((gf - bf) / delta) % 6.0);
    } else if (maxc == gf) {
      h = 60.0 * (((bf - rf) / delta) + 2.0);
    } else {
      h = 60.0 * (((rf - gf) / delta) + 4.0);
    }

    if (h < 0) h += 360.0;
    return _Hsv(h, s, v);
  }

  static double _max3(double a, double b, double c) {
    double m = a;
    if (b > m) m = b;
    if (c > m) m = c;
    return m;
  }

  static double _min3(double a, double b, double c) {
    double m = a;
    if (b < m) m = b;
    if (c < m) m = c;
    return m;
  }
}

class _Hsv {
  const _Hsv(this.h, this.s, this.v);
  final double h; // 0..360
  final double s; // 0..1
  final double v; // 0..1
}