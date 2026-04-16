import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class LiveViewPage extends StatefulWidget {
  const LiveViewPage({
    super.key,
    required this.streamUrl,
    required this.wsUrl,
    required this.captureUrl,
  });

  final String streamUrl;
  final String wsUrl;
  final String captureUrl;

  @override
  State<LiveViewPage> createState() => _LiveViewPageState();
}

class _LiveViewPageState extends State<LiveViewPage> {
  WebSocketChannel? _ch;
  bool _ledOn = false;
  bool _capturing = false;
  DateTime? _lastCaptureAt;

  bool _wsReady = false;
  String? _wsError;

  @override
  void initState() {
    super.initState();
    _initWs();
  }

  Future<void> _captureAndReturn() async {
    final now = DateTime.now();

    if (_capturing) return;

    if (_lastCaptureAt != null &&
        now.difference(_lastCaptureAt!).inMilliseconds < 1500) {
      return;
    }

    _lastCaptureAt = now;

    setState(() => _capturing = true);

    try {
    final res = await http
        .get(Uri.parse(widget.captureUrl))
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/exam_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final path =
        '${imagesDir.path}/esp_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await File(path).writeAsBytes(res.bodyBytes, flush: true);

    if (!mounted) return;
    Navigator.pop(context, path);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal capture ESP32: $e')),
    );
    setState(() => _capturing = false);
  }
}

  void _initWs() {
    // WS optional
    if (widget.wsUrl.trim().isEmpty) return;

    try {
      _ch = WebSocketChannel.connect(Uri.parse(widget.wsUrl));

      // Cara sederhana untuk “nandain” WS hidup:
      // kalau listen dapat event/error/close, kita update status.
_ch!.stream.listen(
  (message) async {
    final msg = message.toString().trim().toLowerCase();

    if (!_wsReady && mounted) {
      setState(() {
        _wsReady = true;
        _wsError = null;
      });
    }

    // trigger dari tombol hardware ESP32
  if (msg.contains('"status":1')) {
    await _captureAndReturn();
  }
  },
  onError: (e) {
    if (!mounted) return;
    setState(() {
      _wsReady = false;
      _wsError = e.toString();
    });
  },
  onDone: () {
    if (!mounted) return;
    setState(() {
      _wsReady = false;
      _wsError = 'WebSocket closed';
    });
  },
);
    } catch (e) {
      _wsReady = false;
      _wsError = 'Gagal connect WS: $e';
    }
  }

  @override
  void dispose() {
    try {
      _ch?.sink.close();
    } catch (_) {}
    super.dispose();
  }

void _toggleLed() {
  setState(() => _ledOn = !_ledOn);

  final cmd = _ledOn ? 'LED:1' : 'LED:0';

  try {
    _ch?.sink.add(cmd);
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _wsReady = false;
      _wsError = 'Gagal kirim WS: $e';
    });
  }
}

  @override
  Widget build(BuildContext context) {
    final showWsInfo = widget.wsUrl.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live View ESP32-CAM'),
        actions: [
          if (showWsInfo)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Icon(
                  _wsReady ? Icons.wifi : Icons.wifi_off,
                  size: 18,
                ),
              ),
            ),
          IconButton(
            onPressed: showWsInfo ? _toggleLed : null,
            icon: Icon(_ledOn ? Icons.flash_on : Icons.flash_off),
            tooltip: 'Toggle LED',
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Mjpeg(
                stream: widget.streamUrl,
                isLive: true,
                error: (context, error, stack) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Gagal memuat stream.\n\n$error\n\n'
                    'Pastikan HP tersambung WiFi ESP32 & URL benar:\n${widget.streamUrl}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              _capturing
                  ? 'Sedang mengambil gambar dari ESP32...'
                  : 'Tekan tombol hardware pada ESP32 untuk capture.',
              textAlign: TextAlign.center,
            ),
          ),
          if (showWsInfo)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _wsReady
                    ? 'WS: Connected (${widget.wsUrl})'
                    : 'WS: Not connected ${_wsError != null ? "\n$_wsError" : ""}',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
  }