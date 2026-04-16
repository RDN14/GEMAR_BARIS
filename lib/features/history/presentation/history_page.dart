import 'package:flutter/material.dart';

import '../../../widgets/app_topbar.dart';
import '../../exam/data/exam_repository.dart';
import '../../exam/data/exam_hive.dart';
import '../../exam/domain/exam_models.dart';
import '../../exam/presentation/exam_page.dart';
import 'history_pdf_exporter.dart';
import '../../../core/utils/top_notice.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _repo = ExamRepository();
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ExamSessionHive> get _sessions {
    final all = _repo.all();

    if (_query.trim().isEmpty) {
      return all;
    }

    final q = _query.toLowerCase();
    return all.where((e) {
      final name = e.patientName.toLowerCase();
      return name.contains(q);
    }).toList();
  }

  Future<void> _openEdit(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamPage(editSessionId: id),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteSession(String id) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Hapus riwayat?'),
            content: const Text('Data pemeriksaan ini akan dihapus permanen.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await _repo.delete(id);

    if (!mounted) return;
    showTopNotice(
      context,
      message: 'Riwayat berhasil dihapus',
    );
    setState(() {});
  }

  Future<void> _exportPdf(ExamSessionHive session) async {
    try {
      await HistoryPdfExporter.exportSession(session);
    } catch (e) {
      if (!mounted) return;
      showTopNotice(
        context,
        message: 'Gagal export PDF: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;

    return Scaffold(
      appBar: const AppTopBar(
        title: 'Riwayat',
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama pasien...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: sessions.isEmpty
                ? const _EmptyHistory()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: sessions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final s = sessions[index];
                      final summary = computeSummary(
                        ExamRepository.mapItemsFromHive(s.items),
                      );

                      return _HistoryCard(
                        session: s,
                        category: summary.category,
                        averageText: summary.averageScore == null
                            ? '-'
                            : summary.averageScore!.toStringAsFixed(2),
                        onEdit: () => _openEdit(s.id),
                        onDelete: () => _deleteSession(s.id),
                        onExportPdf: () => _exportPdf(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_outlined,
              size: 60,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada riwayat pemeriksaan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Data yang disimpan dari halaman pemeriksaan akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.session,
    required this.category,
    required this.averageText,
    required this.onEdit,
    required this.onDelete,
    required this.onExportPdf,
  });

  final ExamSessionHive session;
  final String category;
  final String averageText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onExportPdf;

  String get _dateText {
    final d = session.date;
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.patientName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text('Tanggal: $_dateText'),
            Text('Usia: ${session.age?.toString() ?? '-'}'),
            Text('Jenis kelamin: ${session.gender ?? '-'}'),
            const SizedBox(height: 8),
            Text('Rata-rata skor: $averageText'),
            Text('Kategori: $category'),
            Center(
              child: SizedBox(
                width: 180,
                child: OutlinedButton.icon(
                  onPressed: onExportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export PDF'),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}