import 'dart:io';

class PatientInfo {
  PatientInfo({
    required this.name,
    required this.age,
    required this.gender,
    required this.date,
  });

  final String name;
  final int? age;
  final String? gender;
  final DateTime date;
}

class AnalysisItem {
  AnalysisItem({
    required this.id,
    this.toothCode,
    this.toothLabel,
    this.surfaceLabel,
    this.inputPath,
    this.resultPath,
    this.score,
    this.plaqueRatio,
    this.note,
    this.isAuto = true,
  });

  final String id;

  String? toothCode;
  String? toothLabel;
  String? surfaceLabel;

  String? inputPath;
  String? resultPath;

  int? score;
  double? plaqueRatio;

  String? note;
  bool isAuto;

  File? get inputFile => inputPath == null ? null : File(inputPath!);
  File? get resultFile => resultPath == null ? null : File(resultPath!);
}

class ExamSummary {
  ExamSummary({
    required this.averageScore,
    required this.category,
  });

  final double? averageScore;
  final String category;
}

ExamSummary computeSummary(List<AnalysisItem> items) {
  final scores = items.map((e) => e.score).whereType<int>().toList();

  if (scores.isEmpty) {
    return ExamSummary(
      averageScore: null,
      category: '-',
    );
  }

  final sum = scores.fold<int>(0, (a, b) => a + b);
  final avg = sum / scores.length;

  String cat;
  if (avg < 2) {
    cat = 'Rendah';
  } else if (avg < 4) {
    cat = 'Sedang';
  } else {
    cat = 'Tinggi';
  }

  return ExamSummary(
    averageScore: avg,
    category: cat,
  );
}