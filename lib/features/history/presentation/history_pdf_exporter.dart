import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../exam/data/exam_repository.dart';
import '../../exam/data/exam_hive.dart';
import '../../exam/domain/exam_models.dart';

class HistoryPdfExporter {
  static Future<void> exportSession(ExamSessionHive session) async {
    final pdf = pw.Document();

    final items = ExamRepository.mapItemsFromHive(session.items);
    final summary = computeSummary(items);

    Uint8List? kopBytes;
    try {
      kopBytes = (await rootBundle.load('assets/images/header_kop.png'))
          .buffer
          .asUint8List();
    } catch (_) {
      kopBytes = null;
    }

    final kopImage = kopBytes != null ? pw.MemoryImage(kopBytes) : null;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          if (kopImage != null)
            pw.Center(
              child: pw.Image(
                kopImage,
                fit: pw.BoxFit.contain,
                width: PdfPageFormat.a4.availableWidth,
              ),
            ),

          pw.SizedBox(height: 8),

          pw.Container(
            height: 2,
            color: PdfColors.black,
          ),

          pw.SizedBox(height: 12),

          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('Nama', session.patientName),
                _infoRow('Usia', session.age?.toString() ?? '-'),
                _infoRow('Jenis Kelamin', session.gender ?? '-'),
                _infoRow(
                  'Tanggal',
                  '${session.date.day}/${session.date.month}/${session.date.year}',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            height: 1,
            color: PdfColors.black,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('Nama', session.patientName),
                _infoRow('Usia', session.age?.toString() ?? '-'),
                _infoRow('Jenis Kelamin', session.gender ?? '-'),
                _infoRow(
                  'Tanggal',
                  '${session.date.day}/${session.date.month}/${session.date.year}',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Ringkasan',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow(
                  'Rata-rata skor',
                  summary.averageScore == null
                      ? '-'
                      : summary.averageScore!.toStringAsFixed(2),
                ),
                _infoRow('Kategori', summary.category),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Detail Pemeriksaan',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          ...items.map((item) => _buildItemSection(item)),
          if ((session.suggestion ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Saran',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(session.suggestion!.trim()),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'laporan_${session.patientName}.pdf',
    );
  }

  static pw.Widget _buildItemSection(AnalysisItem item) {
    pw.MemoryImage? inputImage;
    pw.MemoryImage? resultImage;

    try {
      if (item.inputPath != null && File(item.inputPath!).existsSync()) {
        inputImage = pw.MemoryImage(File(item.inputPath!).readAsBytesSync());
      }
    } catch (_) {}

    try {
      if (item.resultPath != null && File(item.resultPath!).existsSync()) {
        resultImage = pw.MemoryImage(File(item.resultPath!).readAsBytesSync());
      }
    } catch (_) {}

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            item.toothLabel ?? '-',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Input', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      height: 120,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                      ),
                      child: inputImage != null
                          ? pw.Image(inputImage, fit: pw.BoxFit.contain)
                          : pw.Text('-', style: const pw.TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Hasil', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      height: 120,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                      ),
                      child: resultImage != null
                          ? pw.Image(resultImage, fit: pw.BoxFit.contain)
                          : pw.Text('-', style: const pw.TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _infoRow('Skor', item.score?.toString() ?? '-'),
          _infoRow(
            'Plak',
            item.plaqueRatio == null
                ? '-'
                : '${(item.plaqueRatio! * 100).toStringAsFixed(1)}%',
          ),
          _infoRow('Catatan', item.note?.trim().isNotEmpty == true ? item.note! : '-'),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }
}