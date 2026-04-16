class PlaqueDebugResult {
  final double plaqueRatio;
  final int validDetections;
  final double maxPlaqueScore;
  final double avgPlaqueScore;

  const PlaqueDebugResult({
    required this.plaqueRatio,
    required this.validDetections,
    required this.maxPlaqueScore,
    required this.avgPlaqueScore,
  });
}

class PlaqueDecoder {
  // YOLOv8-seg TFLite:
  // 0..3  = bbox
  // 4..7  = class scores (4 class)
  // 8..39 = mask coeffs (32)

  static const int _plaqueChannel = 4;

  static PlaqueDebugResult analyzeDetections(
    List<List<List<double>>> output0,
  ) {
    if (output0.isEmpty) {
      return const PlaqueDebugResult(
        plaqueRatio: 0,
        validDetections: 0,
        maxPlaqueScore: 0,
        avgPlaqueScore: 0,
      );
    }

    final tensor = output0[0]; // [40][8400]
    final plaqueScores = tensor[_plaqueChannel];

    int validDetections = 0;
    int plaqueWins = 0;
    double maxPlaqueScore = 0;
    double plaqueSum = 0;

    for (final score in plaqueScores) {
      if (score > maxPlaqueScore) {
        maxPlaqueScore = score;
      }

      // lebih sensitif: kandidat valid
      if (score > 0.06) {
        validDetections++;
        plaqueSum += score;
      }

      // lebih sensitif: plaque positif
      if (score > 0.22) {
        plaqueWins++;
      }
    }

    final avgPlaqueScore =
        validDetections == 0 ? 0.0 : plaqueSum / validDetections;

    double plaqueRatio =
        validDetections == 0 ? 0.0 : plaqueWins / validDetections;

    // fallback ringan:
    // kalau ada sinyal plaque kecil tapi belum cukup kuat,
    // jangan jatuh ke nol mutlak
    if (plaqueRatio == 0.0 && maxPlaqueScore > 0.12) {
      plaqueRatio = 0.05;
    }

    if (plaqueRatio == 0.0 && avgPlaqueScore > 0.08) {
      plaqueRatio = 0.03;
    }

    return PlaqueDebugResult(
      plaqueRatio: plaqueRatio,
      validDetections: validDetections,
      maxPlaqueScore: maxPlaqueScore,
      avgPlaqueScore: avgPlaqueScore,
    );
  }
}