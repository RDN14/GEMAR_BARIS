import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'plaque_decoder.dart';
import 'plaque_mask_renderer.dart';
import 'plaque_score_calculator.dart';
import 'plaque_tflite_service.dart';

class PlaqueAiResult {
  final double plaqueRatio;
  final int score;
  final String resultImagePath;

  const PlaqueAiResult({
    required this.plaqueRatio,
    required this.score,
    required this.resultImagePath,
  });
}

class PlaqueAiRunner {
  static final PlaqueTfliteService _service = PlaqueTfliteService();
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _service.loadModel();
    _loaded = true;
  }

  static Future<PlaqueAiResult> analyzeImage({
    required String inputPath,
  }) async {
    await ensureLoaded();

    final bytes = await File(inputPath).readAsBytes();

    final result = _service.run(bytes);

    final output0 = result['output0'] as List<List<List<double>>>;
    final output1 = result['output1'] as List<List<List<List<double>>>>;

    final debug = PlaqueDecoder.analyzeDetections(output0);
    final score = PlaqueScoreCalculator.calculateScore(debug.plaqueRatio);

    final overlayBytes = PlaqueMaskRenderer.renderMask(
      originalBytes: bytes,
      output0: output0,
      output1: output1,
    );

    final resultPath = await _saveOverlayImage(
      overlayBytes ?? bytes,
      inputPath,
    );

    return PlaqueAiResult(
      plaqueRatio: debug.plaqueRatio,
      score: score,
      resultImagePath: resultPath,
    );
  }

  static Future<String> _saveOverlayImage(
    Uint8List bytes,
    String inputPath,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final resultDir = Directory('${dir.path}/exam_results');

    if (!await resultDir.exists()) {
      await resultDir.create(recursive: true);
    }

    final fileName =
        'result_${DateTime.now().millisecondsSinceEpoch}_${inputPath.hashCode}.png';

    final file = File('${resultDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    return file.path;
  }
}