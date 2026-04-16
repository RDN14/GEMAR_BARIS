import 'package:flutter/material.dart';

import '../../../widgets/app_topbar.dart';
import '../../exam/presentation/exam_page.dart';
import '../../history/presentation/history_page.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openExam(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExamPage()),
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(
        title: 'Beranda',
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(
            onExamTap: () => _openExam(context),
            onHistoryTap: () => _openHistory(context),
          ),
          const SizedBox(height: 16),
          const _InfoCard(
            title: 'Alur Penggunaan',
            items: [
              'Isi data pasien',
              'Ambil / upload foto 6 gigi',
              'Lakukan analisis',
              'Lihat skor dan ringkasan',
              'Simpan ke riwayat',
            ],
          ),
          const SizedBox(height: 16),
          const _InfoCard(
            title: 'Tentang Aplikasi',
            items: [
              'RMD membantu monitoring plak gigi secara digital.',
              'Hasil pemeriksaan dapat disimpan dan ditinjau kembali.',
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.onExamTap,
    required this.onHistoryTap,
  });

  final VoidCallback onExamTap;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RMD – Real-time Monitoring of Dental Plaque',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mulai pemeriksaan baru atau buka data riwayat pasien.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onExamTap,
                icon: const Icon(Icons.medical_services_outlined),
                label: const Text('Mulai Pemeriksaan'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onHistoryTap,
                icon: const Icon(Icons.history_outlined),
                label: const Text('Lihat Riwayat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...items.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.circle, size: 8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}