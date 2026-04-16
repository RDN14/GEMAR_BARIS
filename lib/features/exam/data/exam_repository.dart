import 'package:hive/hive.dart';

import '../domain/exam_models.dart';
import 'exam_hive.dart';

class ExamRepository {
  final Box<ExamSessionHive> _box = Hive.box<ExamSessionHive>(ExamHiveBoxes.sessions);

  List<ExamSessionHive> all() {
    final list = _box.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  ExamSessionHive? getById(String id) {
    return _box.values.cast<ExamSessionHive?>().firstWhere(
          (e) => e?.id == id,
          orElse: () => null,
        );
  }

  Future<void> upsert(ExamSessionHive session) async {
    // key pakai id
    await _box.put(session.id, session);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  // mapper helper (kalau kamu nanti mau pakai domain object murni)
  static List<AnalysisItemHive> mapItemsToHive(List<AnalysisItem> items) {
    return items
        .map(
          (e) => AnalysisItemHive(
            id: e.id,
            toothLabel: e.toothLabel,
            inputPath: e.inputPath,
            resultPath: e.resultPath,
            score: e.score,
            note: e.note,
          ),
        )
        .toList();
  }

  static List<AnalysisItem> mapItemsFromHive(List<AnalysisItemHive> items) {
    return items
        .map(
          (e) => AnalysisItem(
            id: e.id,
            toothLabel: e.toothLabel,
            inputPath: e.inputPath,
            resultPath: e.resultPath,
            score: e.score,
            note: e.note,
          ),
        )
        .toList();
  }
}