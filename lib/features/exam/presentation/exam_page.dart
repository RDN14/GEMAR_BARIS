// lib/features/exam/presentation/exam_page.dart
import 'dart:io';

import '../../../core/ai/plaque_ai_runner.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/top_notice.dart';

import '../../../core/utils/dialogs.dart';
import '../../../widgets/app_topbar.dart';
import '../../../widgets/section_title.dart';
import '../data/exam_hive.dart';
import '../data/exam_repository.dart';
import '../domain/exam_models.dart';
import '../../detection/presentation/live_view_page.dart';

class _FixedToothSpec {
  const _FixedToothSpec({required this.code, required this.label, required this.surface});
  final String code;
  final String label;
  final String surface;
}

class ExamPage extends StatefulWidget {
  const ExamPage({super.key, this.editSessionId});
  final String? editSessionId;

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final _repo = ExamRepository();
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  // pasien
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _suggestionController = TextEditingController();
  String? _gender;
  DateTime _date = DateTime.now();

  // 6 item FIX
  final List<AnalysisItem> _items = [];
  bool _analyzing = false;

  late final String _sessionId;
  DateTime? _createdAt;

  static const List<_FixedToothSpec> _fixedTeeth = [
    _FixedToothSpec(code: '16', label: 'Geraham kanan atas', surface: 'Bukal (pipi)'),
    _FixedToothSpec(code: '11', label: 'Incisivus kanan atas', surface: 'Labial (bibir)'),
    _FixedToothSpec(code: '26', label: 'Geraham kiri atas', surface: 'Bukal (pipi)'),
    _FixedToothSpec(code: '36', label: 'Geraham kiri bawah', surface: 'Lingual (lidah)'),
    _FixedToothSpec(code: '31', label: 'Incisivus kiri bawah', surface: 'Labial (bibir)'),
    _FixedToothSpec(code: '46', label: 'Geraham kanan bawah', surface: 'Lingual (lidah)'),
  ];

  @override
  void initState() {
    super.initState();
    _sessionId = widget.editSessionId ?? _uuid.v4();
    if (widget.editSessionId != null) {
      _loadForEdit(widget.editSessionId!);
    } else {
      _initFixedItems();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _suggestionController.dispose();
    super.dispose();
  }

  void _initFixedItems() {
    _items
      ..clear()
      ..addAll(List.generate(_fixedTeeth.length, (i) {
        final t = _fixedTeeth[i];
        return AnalysisItem(
          id: _uuid.v4(),
          toothCode: t.code,
          toothLabel: t.label,
          surfaceLabel: t.surface,
        );
      }));
  }


  void _loadForEdit(String id) {
    final s = _repo.getById(id);
    if (s == null) {
      _initFixedItems();
      return;
    }

    _nameController.text = s.patientName;
    _ageController.text = s.age?.toString() ?? '';
    _gender = s.gender;
    _date = s.date;
    _suggestionController.text = s.suggestion ?? '';
    _createdAt = s.createdAt;

    final loaded = ExamRepository.mapItemsFromHive(s.items);

    _items.clear();
    for (int i = 0; i < _fixedTeeth.length; i++) {
      final t = _fixedTeeth[i];
      final item = (i < loaded.length)
          ? loaded[i]
          : AnalysisItem(
              id: _uuid.v4(),
              toothCode: t.code,
              toothLabel: t.label,
              surfaceLabel: t.surface,
            );

      item.toothCode = t.code;
      item.toothLabel = t.label;
      item.surfaceLabel = t.surface;

      _items.add(item);
    }

    setState(() {});
  }

  ExamSummary get _summary => computeSummary(_items);

  String _scoreLabel(int? score) {
    if (score == null) return '-';

    switch (score) {
      case 1:
        return 'Sangat Bersih';
      case 2:
        return 'Plak Ringan';
      case 3:
        return 'Plak Sedang';
      case 4:
        return 'Plak Banyak';
      case 5:
        return 'Plak Sangat Banyak';
      default:
        return '-';
    }
  }
  // -----------------------
  // UI actions
  // -----------------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: _date,
    );
    if (!mounted) return;
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _showImageSourceOptions(int index) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Upload dari Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Live View ESP32'),
              onTap: () => Navigator.pop(context, 'esp32'),
            ),
          ],
        ),
      );
    },
  );

    if (!mounted || choice == null) return;

    if (choice == 'gallery') {
      await _pickImageForItem(index);
    } else if (choice == 'esp32') {
      await _openLiveViewForItem(index);
    }
  }

  Future<void> _openLiveViewForItem(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LiveViewPage(
          streamUrl: 'http://192.168.4.1:81/stream',
          wsUrl: 'ws://192.168.4.1/ws',
          captureUrl: 'http://192.168.4.1/capture',
        ),
      ),
    );

    if (!mounted || result == null) return;

    if (result == "gallery") {
      await _pickImageForItem(index);
      return;
    }

    final capturedPath = result as String;

    try {
      final item = _items[index];

      setState(() {
        item.inputPath = capturedPath;
        item.resultPath = null;
        item.score = null;
        item.plaqueRatio = null;
        item.isAuto = true;
      });

      final aiResult = await PlaqueAiRunner.analyzeImage(
        inputPath: capturedPath,
      );

      if (!mounted) return;

      setState(() {
        item.resultPath = aiResult.resultImagePath;
        item.score = aiResult.score;
        item.plaqueRatio = aiResult.plaqueRatio;
        item.isAuto = true;
      });

      showTopNotice(
        context,
        message: 'Foto ESP32 berhasil dianalisis ✅',
      );
    } catch (e) {
      if (!mounted) return;
      showTopNotice(
        context,
        message: 'Gagal analisis: $e',
        success: false,
      );
    }
  }


  Future<void> _pickImageForItem(int index) async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final item = _items[index];

      setState(() {
        item.inputPath = picked.path;
        item.resultPath = null;
        item.score = null;
        item.plaqueRatio = null;
        item.isAuto = true;
      });

      final aiResult = await PlaqueAiRunner.analyzeImage(
        inputPath: picked.path,
      );

      setState(() {
        item.resultPath = aiResult.resultImagePath;
        item.score = aiResult.score;
        item.plaqueRatio = aiResult.plaqueRatio;
        item.isAuto = true;
      });

      if (!mounted) return;
      showTopNotice(
        context,
        message: 'Analisis AI selesai ✅',
      );
    } catch (e) {
      if (!mounted) return;
      showTopNotice(
        context,
        message: 'Gagal analisis AI: $e',
        success: false,
      );
    }
  }

  Future<void> _analyzeAll() async {
    if (_items.any((e) => e.inputPath == null)) {
      if (!mounted) return;
      showTopNotice(
        context,
        message: 'Lengkapi dulu semua 6 foto gigi.',
        success: false,
      );
      return;
    }

    setState(() => _analyzing = true);

    try {
      for (final item in _items) {
        final inputPath = item.inputPath!;
        final aiResult = await PlaqueAiRunner.analyzeImage(
          inputPath: inputPath,
        );

        item.score = aiResult.score;
        item.plaqueRatio = aiResult.plaqueRatio;
        item.resultPath = aiResult.resultImagePath;
        item.isAuto = true;
      }

      if (!mounted) return;
      setState(() {});
      showTopNotice(
        context,
        message: 'Analisis AI selesai ✅',
      );
    } catch (e) {
      if (!mounted) return;
      showTopNotice(
        context,
        message: 'Error analisis: $e',
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() => _analyzing = false);
      }
    }
  }

  Future<void> _saveSession() async {
    final ok = await confirmDialog(
      context,
      title: 'Simpan pemeriksaan?',
      message: 'Data pasien dan hasil analisis akan disimpan ke Riwayat.',
      okText: 'OK',
      cancelText: 'Batal',
    );

    if (!mounted) return;
    if (!ok) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showTopNotice(
        context,
        message: 'Nama pasien wajib diisi.',
        success: false,
      );
      return;
    }

    final age = int.tryParse(_ageController.text.trim());
    final now = DateTime.now();

    final hive = ExamSessionHive(
      id: _sessionId,
      patientName: name,
      age: age,
      gender: _gender,
      date: _date,
      items: ExamRepository.mapItemsToHive(_items),
      suggestion: _suggestionController.text.trim().isEmpty ? null : _suggestionController.text.trim(),
      createdAt: _createdAt ?? now,
      updatedAt: now,
    );

    await _repo.upsert(hive);

    if (!mounted) return;
    showTopNotice(
      context,
      message: 'Tersimpan ✅',
    );
    Navigator.pop(context);
  }

  Future<void> _resetAll() async {
    final ok = await confirmDialog(
      context,
      title: 'Reset form?',
      message: 'Semua input akan dikosongkan (tidak menghapus Riwayat).',
      okText: 'OK',
      cancelText: 'Batal',
    );

    if (!mounted) return;
    if (!ok) return;

    setState(() {
      _nameController.clear();
      _ageController.clear();
      _suggestionController.clear();
      _gender = null;
      _date = DateTime.now();
      _initFixedItems();
    });
  }

    void _openLiveView() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LiveViewPage(
            streamUrl: 'http://192.168.4.1:81/stream',
            wsUrl: 'ws://192.168.4.1/ws',
            captureUrl: 'http://192.168.4.1/capture',
          ),
        ),
      );
    }

  // -----------------------
  // UI
  // -----------------------

  @override
  Widget build(BuildContext context) {
    final dateText = '${_date.day}/${_date.month}/${_date.year}';
    final avg = _summary.averageScore;
    final avgText = avg == null ? '-' : avg.toStringAsFixed(2);

    return Scaffold(
    appBar: AppTopBar(
      title: widget.editSessionId == null ? 'Pemeriksaan' : 'Edit Pemeriksaan',
      centerTitle: true,
    ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Data pasien
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('Data Pasien'),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nama', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Usia', prefixIcon: Icon(Icons.numbers_outlined)),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Jenis Kelamin', prefixIcon: Icon(Icons.wc_outlined)),
                items: const [
                  DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                  DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Tanggal', prefixIcon: Icon(Icons.calendar_today_outlined)),
                  child: Text(dateText),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // Analisis
          const SectionTitle('Input Analisis (6 gigi FIX)'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _analyzing ? null : _analyzeAll,
              icon: const Icon(Icons.analytics_outlined),
              label: Text(_analyzing ? 'Memproses...' : 'Analisis'),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_items.length, _analysisCard),

          const SizedBox(height: 16),

          // Ringkasan
          const SectionTitle('Ringkasan'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Rata-rata skor: $avgText'),
              const SizedBox(height: 6),
              Text('Kategori: ${_summary.category}'),
            ]),
          ),

          const SizedBox(height: 16),

          // Saran
          const SectionTitle('Saran'),
          const SizedBox(height: 8),
          TextField(
            controller: _suggestionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Saran', prefixIcon: Icon(Icons.notes_outlined)),
          ),

          const SizedBox(height: 18),

          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveSession,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetAll,
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('Reset'),
              ),
            ),
          ]),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openLiveView,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Live View'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }

  Widget _analysisCard(int index) {
    final item = _items[index];
    final scoreText = item.score?.toString() ?? '-';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              item.toothLabel ?? 'Item ${index + 1}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _imageBox(
                    title: 'Input',
                    file: item.inputFile,
                    onTap: () => _showImageSourceOptions(index),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _imageBox(
                    title: 'Hasil',
                    file: item.resultFile,
                    onTap: null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            const SizedBox(height: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Skor: ', style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      scoreText,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      item.score == null ? 'Tekan Analisis' : 'Otomatis',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Plak: ${item.plaqueRatio == null ? '-' : '${(item.plaqueRatio! * 100).toStringAsFixed(1)}%'}',
                ),
                const SizedBox(height: 4),
                Text('Interpretasi: ${_scoreLabel(item.score)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

    Widget _imageBox({required String title, required File? file, required VoidCallback? onTap}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(10),
              color: Colors.black12,
            ),
            clipBehavior: Clip.antiAlias,
            child: file == null
                ? Center(
                    child: Text(
                      onTap == null ? title : '$title\n(Tap)',
                      textAlign: TextAlign.center,
                    ),
                  )
                : Image.file(file, fit: BoxFit.cover),
          ),
        ),
      );
    }
  }
