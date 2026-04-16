import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class PlaqueTfliteService {
  Interpreter? _interpreter;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/models/best_float32.tflite',
      options: InterpreterOptions()..threads = 2,
    );
  }

  bool get isLoaded => _interpreter != null;

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }

  Map<String, Object> run(Uint8List imageBytes) {
    if (_interpreter == null) {
      throw Exception('Model belum diload');
    }

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Gagal decode image');
    }

    final resized = img.copyResize(decoded, width: 640, height: 640);
    final input = _imageToTensor(resized);

    final output0 = List.generate(
      1,
      (_) => List.generate(
        40,
        (_) => List.filled(8400, 0.0),
      ),
    );

    final output1 = List.generate(
      1,
      (_) => List.generate(
        160,
        (_) => List.generate(
          160,
          (_) => List.filled(32, 0.0),
        ),
      ),
    );

    _interpreter!.runForMultipleInputs(
      [input],
      {
        0: output0,
        1: output1,
      },
    );

    return {
      'output0': output0,
      'output1': output1,
      'originalWidth': decoded.width,
      'originalHeight': decoded.height,
    };
  }

  List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    return [
      List.generate(640, (y) {
        return List.generate(640, (x) {
          final p = image.getPixel(x, y);
          return [
            p.r / 255.0,
            p.g / 255.0,
            p.b / 255.0,
          ];
        });
      }),
    ];
  }
}