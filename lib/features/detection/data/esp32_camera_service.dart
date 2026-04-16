import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Esp32CameraService {
  Esp32CameraService({
    this.baseHttp = 'http://192.168.4.1',
    this.streamUrl = 'http://192.168.4.1:81/stream',
    this.wsUrl = 'ws://192.168.4.1/ws',
    this.capturePath = '/capture', // sesuaikan kalau firmware-mu beda
  });

  final String baseHttp;
  final String streamUrl;
  final String wsUrl;
  final String capturePath;

  /// Ambil 1 foto JPEG dari ESP32 lalu simpan ke storage aplikasi.
  Future<File> captureToFile() async {
    final uri = Uri.parse('$baseHttp$capturePath');

    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Capture gagal. HTTP ${resp.statusCode}');
    }

    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/esp32_captures');
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final filePath = '${outDir.path}/cap_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(filePath);
    await file.writeAsBytes(resp.bodyBytes, flush: true);
    return file;
  }

  /// WebSocket untuk kirim command ke ESP32 (misalnya kontrol LED).
  WebSocketChannel connectWs() {
    return WebSocketChannel.connect(Uri.parse(wsUrl));
  }

  /// Helper kirim command sekali (connect -> send -> close).
  Future<void> sendWsCommand(String message) async {
    final ch = connectWs();
    ch.sink.add(message);
    await Future.delayed(const Duration(milliseconds: 200));
    await ch.sink.close();
  }
}