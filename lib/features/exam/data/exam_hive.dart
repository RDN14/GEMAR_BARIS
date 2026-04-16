import 'package:hive/hive.dart';

part 'exam_hive.g.dart';

class ExamHiveBoxes {
  static const sessions = 'exam_sessions';
}

@HiveType(typeId: 1)
class ExamSessionHive extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String patientName;

  @HiveField(2)
  int? age;

  @HiveField(3)
  String? gender;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  List<AnalysisItemHive> items;

  @HiveField(6)
  String? suggestion;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime updatedAt;

  ExamSessionHive({
    required this.id,
    required this.patientName,
    required this.age,
    required this.gender,
    required this.date,
    required this.items,
    required this.suggestion,
    required this.createdAt,
    required this.updatedAt,
  });
}

@HiveType(typeId: 2)
class AnalysisItemHive {
  @HiveField(0)
  String id;

  @HiveField(1)
  String? toothLabel;

  @HiveField(2)
  String? inputPath;

  @HiveField(3)
  String? resultPath;

  @HiveField(4)
  int? score;

  @HiveField(5)
  String? note;

  AnalysisItemHive({
    required this.id,
    required this.toothLabel,
    required this.inputPath,
    required this.resultPath,
    required this.score,
    required this.note,
  });
}

void registerHiveAdapters() {
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(ExamSessionHiveAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(AnalysisItemHiveAdapter());
  }
}