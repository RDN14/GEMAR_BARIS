import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:deteksi_plak_gigi/widgets/section_title.dart';

// ✅ core AI
import 'package:deteksi_plak_gigi/core/ai/hsv_plaque_analyzer.dart';

// ✅ ESP32 service + live view page
import 'package:deteksi_plak_gigi/features/detection/data/esp32_camera_service.dart';
import 'package:deteksi_plak_gigi/features/detection/presentation/live_view_page.dart';

/// 1 item analisis (1 foto gigi).
class ExamItem {
  ExamItem({
    required this.id,
    required this.createdAt,
  });

  final String id;
  final DateTime createdAt;

  File? inputImage;
  File? resultImage; // optional (overlay nanti kalau mau)
  int? score; // 1..5
  double? yellowRatio; // debug
}

class DetectionPage extends StatefulWidget {
  const DetectionPage({super.key});

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  // -----------------------------
  // Data pasien
  // -----------------------------
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _suggestionController = TextEditingController();
  String? _gender;
  DateTime? _selectedDate;

  // -----------------------------
  // ESP32 config (AP mode default)
  // -----------------------------
  final _esp32 = Esp32CameraService(
    baseHttp: 'http://192.168.4.1',
    streamUrl: 'http://192.168.4.1:81/stream',
    wsUrl: 'ws://192.168.4.1/ws',
    capturePath: '/capture', // ⚠️ sesuaikan jika firmware kamu beda
  );

  // -----------------------------
  // List item analisis
  // -----------------------------
  final List<ExamItem> _items = [];
  int _activeIndex = 0;
  bool _isBusy = false;

  final _picker = ImagePicker();

  ExamItem? get _activeItem {
    if (_items.isEmpty) return null;
    if (_activeIndex < 0) _activeIndex = 0;
    if (_activeIndex >= _items.length) _activeIndex = _items.length - 1;
    return _items[_activeIndex];
  }

  double? get _averageScore {
    final scores = _items.map((e) => e.score).whereType<int>().toList();
    if (scores.isEmpty) return null;
    final sum = scores.fold<int>(0, (a, b) => a + b);
    return sum / scores.length;
  }

  String get _category {
    final avg = _averageScore;
    if (avg == null) return '-';
    if (avg < 2) return 'Rendah';
    if (avg < 4) return 'Sedang';
    return 'Tinggi';
  }

  @override
  void initState() {
    super.initState();
    // 1 item default
    _items.add(
      ExamItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _suggestionController.dispose();
    super.dispose();
  }

  // -----------------------------
  // Dialog OK / Batal
  // -----------------------------
  Future<bool> _confirmDialog({
    required String title,
    required String message,
    String okText = 'OK',
    String cancelText = 'Batal',
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(okText),
            ),
          ],
        );
      },
    );
    return res == true;
  }

  // -----------------------------
  // Pick date
  // -----------------------------
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: _selectedDate ?? now,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // -----------------------------
  // Item controls
  // -----------------------------
  void _addNewItem() {
    setState(() {
      _items.add(
        ExamItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          createdAt: DateTime.now(),
        ),
      );
      _activeIndex = _items.length - 1;
    });
  }

  void _removeActiveItem() {
    if (_items.isEmpty) return;
    setState(() {
      _items.removeAt(_activeIndex);
      if (_items.isEmpty) {
        _items.add(
          ExamItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            createdAt: DateTime.now(),
          ),
        );
        _activeIndex = 0;
      } else {
        _activeIndex = _activeIndex.clamp(0, _items.length - 1);
      }
    });
  }

  // -----------------------------
  // Pick image from gallery
  // -----------------------------
  Future<void> _pickImageForActive() async {
    final active = _activeItem;
    if (active == null) return;

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (picked == null) return;

    final nameLower = picked.name.toLowerCase();
    final allowed = ['.jpg', '.jpeg', '.png', '.heic', '.heif', '.webp'];
    final ok = allowed.any((e) => nameLower.endsWith(e));

    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format tidak didukung. Gunakan JPG/PNG/HEIC/WEBP.')),
      );
      return;
    }

    setState(() {
      active.inputImage = File(picked.path);
      active.resultImage = null;
      active.score = null;
      active.yellowRatio = null;
    });
  }

  // -----------------------------
  // Capture from ESP32 (HTTP)
  // -----------------------------
  Future<void> _captureFromEsp32() async {
    final active = _activeItem;
    if (active == null) return;

    setState(() => _isBusy = true);
    try {
      final file = await _esp32.captureToFile();

      setState(() {
        active.inputImage = file;
        active.resultImage = null;
        active.score = null;
        active.yellowRatio = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Foto dari ESP32 berhasil diambil')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture ESP32 gagal: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _clearActive() {
    final active = _activeItem;
    if (active == null) return;
    setState(() {
      active.inputImage = null;
      active.resultImage = null;
      active.score = null;
      active.yellowRatio = null;
    });
  }

  // -----------------------------
  // Analyze (HSV)
  // -----------------------------
  Future<void> _analyzeActive() async {
    final active = _activeItem;
    if (active == null) return;

    final input = active.inputImage;
    if (input == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload / Capture gambar dulu untuk item ini.')),
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      final res = await HSVPlaqueAnalyzer.analyze(input);

      setState(() {
        active.score = res.score;
        active.yellowRatio = res.yellowRatio;
        active.resultImage = null; // overlay nanti kalau kamu mau
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Skor: ${res.score} | kuning: ${res.yellowRatio.toStringAsFixed(3)} '
            '(Y=${res.yellowCount}/${res.sampleCount})',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error analisis: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // -----------------------------
  // Save/Reset (sementara)
  // -----------------------------
  Future<void> _onSavePressed() async {
    final ok = await _confirmDialog(
      title: 'Simpan pemeriksaan?',
      message: 'Data pasien + daftar analisis akan disimpan ke Riwayat.',
      okText: 'Simpan',
      cancelText: 'Batal',
    );
    if (!ok) return;

    // TODO: di tahap berikutnya: simpan ke Hive sesuai arsitektur ExamRepository kamu
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Tersimpan (sementara). Next: simpan ke Hive.')),
    );
  }

  Future<void> _onResetPressed() async {
    final ok = await _confirmDialog(
      title: 'Reset form?',
      message: 'Semua input pasien & daftar analisis akan dihapus.',
      okText: 'Reset',
      cancelText: 'Batal',
    );
    if (!ok) return;

    setState(() {
      _nameController.clear();
      _ageController.clear();
      _suggestionController.clear();
      _gender = null;
      _selectedDate = null;

      _items
        ..clear()
        ..add(
          ExamItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            createdAt: DateTime.now(),
          ),
        );

      _activeIndex = 0;
      _isBusy = false;
    });
  }

  // -----------------------------
  // Open Live View
  // -----------------------------
  void _openLiveView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveViewPage(
          streamUrl: _esp32.streamUrl,
          wsUrl: _esp32.wsUrl,
          captureUrl: '${_esp32.baseHttp}${_esp32.capturePath}',
        ),
      ),
    );
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final dateText = _selectedDate == null
        ? 'Pilih Tanggal'
        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';

    final avg = _averageScore;
    final avgText = avg == null ? '-' : avg.toStringAsFixed(2);

    final active = _activeItem;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Pemeriksaan',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        leadingWidth: 100,
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Image.asset(
            'assets/images/logo_poltekkes.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Data Pasien'),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Usia'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Jenis Kelamin'),
              items: const [
                DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(dateText),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),

            const SizedBox(height: 16),
            const SectionTitle('Daftar Analisis (Bisa Banyak)'),
            _itemsSelector(),

            const SizedBox(height: 12),
            const SectionTitle('Input & Hasil'),
            Row(
              children: [
                Expanded(
                  child: _imageCard(
                    title: 'Input\n(Upload/Capture)',
                    file: active?.inputImage,
                    onTap: _pickImageForActive,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _imageCard(
                    title: 'Hasil AI\n(overlay opsional)',
                    file: active?.resultImage,
                    onTap: null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isBusy ? null : _pickImageForActive,
                  child: const Text('Unggah'),
                ),
                ElevatedButton(
                  onPressed: _isBusy ? null : _captureFromEsp32,
                  child: const Text('Capture ESP32'),
                ),
                ElevatedButton(
                  onPressed: _isBusy ? null : _analyzeActive,
                  child: Text(_isBusy ? 'Memproses...' : 'Analisis'),
                ),
                OutlinedButton(
                  onPressed: _isBusy ? null : _clearActive,
                  child: const Text('Clear'),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const SectionTitle('Skor & Ringkasan'),
            _summaryCard(avgText: avgText),

            const SizedBox(height: 16),
            const SectionTitle('Saran'),
            TextField(
              controller: _suggestionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Saran'),
            ),

            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _onSavePressed,
                  child: const Text('Simpan'),
                ),
                ElevatedButton(
                  onPressed: _onResetPressed,
                  child: const Text('Reset'),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Center(
              child: OutlinedButton(
                onPressed: _openLiveView,
                child: const Text('Live View'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemsSelector() {
    return Column(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final selected = i == _activeIndex;
            final score = item.score;

            return ChoiceChip(
              selected: selected,
              label: Text('Item ${i + 1}${score != null ? ' • $score' : ''}'),
              onSelected: (_) => setState(() => _activeIndex = i),
            );
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addNewItem,
                icon: const Icon(Icons.add),
                label: const Text('Tambah Item'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _removeActiveItem,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus Item'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard({required String avgText}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Jumlah item: ${_items.length}'),
          const SizedBox(height: 6),
          Text('Rata-rata skor: $avgText'),
          const SizedBox(height: 6),
          Text('Kategori: $_category'),
          const SizedBox(height: 10),
          const Text('Detail item:'),
          const SizedBox(height: 6),
          Column(
            children: List.generate(_items.length, (i) {
              final it = _items[i];
              final score = it.score?.toString() ?? '-';
              final ratio = it.yellowRatio == null ? '-' : it.yellowRatio!.toStringAsFixed(3);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text('Item ${i + 1}')),
                    Text('Skor: $score'),
                    const SizedBox(width: 12),
                    Text('Kuning: $ratio'),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _imageCard({
    required String title,
    required File? file,
    VoidCallback? onTap,
  }) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
            color: Colors.black12,
          ),
          clipBehavior: Clip.antiAlias,
          child: file == null
              ? Center(child: Text(title, textAlign: TextAlign.center))
              : Image.file(file, fit: BoxFit.cover),
        ),
      ),
    );
  }
}