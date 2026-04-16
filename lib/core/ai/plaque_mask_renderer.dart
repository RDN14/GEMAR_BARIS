import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class PlaqueMaskRenderer {
  static Uint8List? renderMask({
    required Uint8List originalBytes,
    required List<List<List<double>>> output0,
    required List<List<List<List<double>>>> output1,
  }) {
    final original = img.decodeImage(originalBytes);
    if (original == null) return null;

    final width = original.width;
    final height = original.height;
    final plaqueSignal = _estimatePlaqueSignal(output0);

    // ===== 1) Bangun mask area gigi =====
    final toothMask = List.generate(
      height,
      (_) => List<bool>.filled(width, false),
    );

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final p = original.getPixel(x, y);
        toothMask[y][x] = _looksLikeTooth(
          p.r.toInt(),
          p.g.toInt(),
          p.b.toInt(),
        );
      }
    }

    final toothMaskSmooth = _smoothBoolMask(toothMask, radius: 2, keepRatio: 0.55);

    // ===== 2) Segmentasi plak berbasis HSV hanya di area gigi =====
    final plaqueMask = List.generate(
      height,
      (_) => List<double>.filled(width, 0.0),
    );

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!toothMaskSmooth[y][x]) continue;

        final p = original.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();

        final hsv = _rgbToHsv(r, g, b);
        final h = hsv[0];
        final s = hsv[1];
        final v = hsv[2];

        // skip highlight / glare
        if (v > 0.92) continue;
        if (v > 0.85 && s < 0.18) continue;

        // plak kuning lebih ketat
        final isYellowPlaque =
            h >= 25 && h <= 55 &&
            s >= 0.35 && s <= 0.90 &&
            v >= 0.25 && v <= 0.85;

        // plak/calc kuning-coklat
        final isBrownPlaque =
            h >= 10 && h <= 30 &&
            s >= 0.35 &&
            v >= 0.12 && v <= 0.72;

        // kalkulus abu-kusam
        final isGrayCalculus =
            s <= 0.18 &&
            v >= 0.20 && v <= 0.65 &&
            _brightness(r, g, b) < 0.65;

        if (isYellowPlaque || isBrownPlaque || isGrayCalculus) {
          // confidence visual sederhana
        double conf = 0.0;

        if (isYellowPlaque) conf += 0.55;
        if (isBrownPlaque) conf += 0.45;
        if (isGrayCalculus) conf += 0.30;

        // makin jenuh dan agak gelap -> makin mungkin plak
        conf += (s * 0.20);
        conf += ((1.0 - v) * 0.20);

        // kurangi area enamel putih bersih
        if (v > 0.80 && s < 0.30) {
          conf -= 0.35;
        }

        plaqueMask[y][x] = conf.clamp(0.0, 1.0);
        }
      }
    }

    // ===== 3) Rapikan mask =====
    final blurRadius = plaqueSignal >= 0.30 ? 3 : 1;
    final threshold = plaqueSignal >= 0.30 ? 0.20 : 0.46;
    final dilateRadius = plaqueSignal >= 0.30 ? 3 : 0;
    final dilateMinValue = plaqueSignal >= 0.30 ? 0.12 : 0.30;
    final minArea = plaqueSignal >= 0.30 ? 28 : 140;

    final blurred = _blurDoubleMask(plaqueMask, radius: blurRadius);

    final thresholded = _thresholdDoubleMask(
      blurred,
      threshold: threshold,
    );

    final expanded = _dilateDoubleMask(
      thresholded,
      radius: dilateRadius,
      minValue: dilateMinValue,
    );

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!toothMaskSmooth[y][x]) {
          expanded[y][x] = 0.0;
        }
      }
    }

    // closing step: isi gap kecil supaya mask lebih rata
    final closed = _blurDoubleMask(expanded, radius: 2);

    final thresholded2 = _thresholdDoubleMask(
      closed,
      threshold: 0.18,
    );

    final cleaned = _removeSmallComponents(
      thresholded2,
      minArea: minArea,
    );

    final finalMask = _blurDoubleMask(
      cleaned,
      radius: plaqueSignal >= 0.30 ? 2 : 1,
    );

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!toothMaskSmooth[y][x]) {
          cleaned[y][x] = 0.0;
        }
      }
    }


    // ===== 4) Overlay ungu klinis =====
    final canvas = img.copyResize(original, width: width, height: height);

    const overlayR = 155.0;
    const overlayG = 60.0;
    const overlayB = 230.0;

    bool hasAny = false;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final v = finalMask[y][x];
        if (v <= 0.0) continue;

        hasAny = true;

        final p = canvas.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();

    final alpha = plaqueSignal >= 0.30
        ? (0.28 + v * 0.50).clamp(0.28, 0.74)
        : (0.10 + v * 0.18).clamp(0.10, 0.24);

        final nr = ((1 - alpha) * r + alpha * overlayR).round().clamp(0, 255);
        final ng = ((1 - alpha) * g + alpha * overlayG).round().clamp(0, 255);
        final nb = ((1 - alpha) * b + alpha * overlayB).round().clamp(0, 255);

        canvas.setPixelRgb(x, y, nr, ng, nb);
      }
    }

    if (!hasAny) {
      return Uint8List.fromList(img.encodePng(original));
    }

    return Uint8List.fromList(img.encodePng(canvas));
  }

  static bool _looksLikeTooth(int r, int g, int b) {
    final hsv = _rgbToHsv(r, g, b);
    final h = hsv[0];
    final s = hsv[1];
    final v = hsv[2];

    // buang area gelap
    if (v < 0.22) return false;

    // warna bibir / jaringan lunak
    if ((h >= 340 || h <= 15) && s > 0.25) {
      return false;
    }

    // buang jaringan lunak: pink / merah / bibir / gusi / lidah
    if ((h >= 330 || h <= 18) && s > 0.16 && v > 0.18) {
      return false;
    }

    if (h >= 0 && h <= 26 && s > 0.28) {
      return false;
    }

    // enamel putih (lebih ketat)
    if (v > 0.55 && s < 0.30) return true;

    // gigi kekuningan
    if (h >= 18 && h <= 65 && s < 0.72 && v > 0.24) return true;

    // abu gigi kusam (jangan terlalu gelap)
    if (s < 0.22 && v > 0.32) return true;

    return false;
  }

  static List<List<bool>> _smoothBoolMask(
    List<List<bool>> src, {
    int radius = 1,
    double keepRatio = 0.5,
  }) {
    final h = src.length;
    final w = src.first.length;
    final out = List.generate(h, (_) => List<bool>.filled(w, false));

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        int total = 0;
        int yes = 0;

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final ny = y + dy;
            final nx = x + dx;
            if (ny < 0 || ny >= h || nx < 0 || nx >= w) continue;

            total++;
            if (src[ny][nx]) yes++;
          }
        }

        out[y][x] = yes >= (total * keepRatio);
      }
    }

    return out;
  }

  static List<List<double>> _blurDoubleMask(List<List<double>> src, {int radius = 1}) {
    final h = src.length;
    final w = src.first.length;
    final out = List.generate(h, (_) => List<double>.filled(w, 0.0));

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double sum = 0.0;
        int count = 0;

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final ny = y + dy;
            final nx = x + dx;
            if (ny < 0 || ny >= h || nx < 0 || nx >= w) continue;

            sum += src[ny][nx];
            count++;
          }
        }

        out[y][x] = count == 0 ? 0.0 : sum / count;
      }
    }

    return out;
  }

  static List<List<double>> _dilateDoubleMask(
    List<List<double>> src, {
    int radius = 1,
    double minValue = 0.1,
  }) {
    final h = src.length;
    final w = src.first.length;
    final out = List.generate(h, (_) => List<double>.filled(w, 0.0));

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double best = 0.0;

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final ny = y + dy;
            final nx = x + dx;

            if (ny < 0 || ny >= h || nx < 0 || nx >= w) continue;

            final v = src[ny][nx];
            if (v > best) best = v;
          }
        }

        out[y][x] = best >= minValue ? best : 0.0;
      }
    }

    return out;
  }

  static List<List<double>> _thresholdDoubleMask(
    List<List<double>> src, {
    required double threshold,
  }) {
    final h = src.length;
    final w = src.first.length;
    final out = List.generate(h, (_) => List<double>.filled(w, 0.0));

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        out[y][x] = src[y][x] >= threshold ? src[y][x] : 0.0;
      }
    }

    return out;
  }

  static double _brightness(int r, int g, int b) {
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
  }

  static List<double> _rgbToHsv(int r, int g, int b) {
    final rf = r / 255.0;
    final gf = g / 255.0;
    final bf = b / 255.0;

    final maxc = math.max(rf, math.max(gf, bf));
    final minc = math.min(rf, math.min(gf, bf));
    final delta = maxc - minc;

    double h = 0.0;
    final s = maxc == 0 ? 0.0 : delta / maxc;
    final v = maxc;

    if (delta != 0) {
      if (maxc == rf) {
        h = 60 * (((gf - bf) / delta) % 6);
      } else if (maxc == gf) {
        h = 60 * (((bf - rf) / delta) + 2);
      } else {
        h = 60 * (((rf - gf) / delta) + 4);
      }
    }

    if (h < 0) h += 360.0;

    return [h, s, v];
  }

  static double _estimatePlaqueSignal(List<List<List<double>>> output0) {
    if (output0.isEmpty) return 0.0;

    final tensor = output0[0];
    if (tensor.length <= 4) return 0.0;

    final plaqueScores = tensor[4];

    double maxScore = 0.0;
    double sum = 0.0;
    int count = 0;

    for (final s in plaqueScores) {
      if (s > maxScore) maxScore = s;
      if (s > 0.06) {
        sum += s;
        count++;
      }
    }

    final avg = count == 0 ? 0.0 : sum / count;

    return math.max(maxScore, avg);
  }
  
  static List<List<double>> _removeSmallComponents(
  List<List<double>> src, {
  int minArea = 40,
}) {
  final h = src.length;
  final w = src.first.length;

  final visited = List.generate(h, (_) => List<bool>.filled(w, false));
  final out = List.generate(h, (_) => List<double>.filled(w, 0.0));

  const dirs = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ];

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (visited[y][x] || src[y][x] <= 0.0) continue;

      final queue = <List<int>>[[y, x]];
      final component = <List<int>>[];
      visited[y][x] = true;

      while (queue.isNotEmpty) {
        final p = queue.removeLast();
        final cy = p[0];
        final cx = p[1];
        component.add([cy, cx]);

        for (final d in dirs) {
          final ny = cy + d[0];
          final nx = cx + d[1];

          if (ny < 0 || ny >= h || nx < 0 || nx >= w) continue;
          if (visited[ny][nx]) continue;
          if (src[ny][nx] <= 0.0) continue;

          visited[ny][nx] = true;
          queue.add([ny, nx]);
        }
      }

      if (component.length >= minArea) {
        for (final p in component) {
          out[p[0]][p[1]] = src[p[0]][p[1]];
        }
      }
    }
  }

  return out;
}
}