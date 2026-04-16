class PlaqueScoreCalculator {
  static int calculateScore(double ratio) {
    if (ratio < 0.05) return 1;
    if (ratio < 0.15) return 2;
    if (ratio < 0.35) return 3;
    if (ratio < 0.60) return 4;
    return 5;
  }

  static String label(int score) {
    switch (score) {
      case 1:
        return "Sangat Bersih";
      case 2:
        return "Plak Ringan";
      case 3:
        return "Plak Sedang";
      case 4:
        return "Plak Banyak";
      case 5:
        return "Plak Sangat Banyak";
      default:
        return "-";
    }
  }
}