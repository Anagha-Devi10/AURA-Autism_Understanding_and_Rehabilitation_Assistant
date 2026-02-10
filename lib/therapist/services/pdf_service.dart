import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class PdfService {
  static Future<String> generateAndSavePdf({
    required String childName,
    required String report,
    required String date,
    required String therapistName,
  }) async {
    final pdf = pw.Document();

    final cleanReport = _sanitizeForPdf(report);
    final formattedDate = _formatDate(date);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo700,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'AURA - Child Development Report',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Child: $childName',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Therapist: $therapistName',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Date: $formattedDate',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                pw.SizedBox(height: 8),
              ],
            );
          }
          return pw.SizedBox();
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Text(
              cleanReport,
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4),
              textAlign: pw.TextAlign.justify,
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Text(
                'This report was generated using AURA AI-assisted therapy tracking system.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ),
          ];
        },
      ),
    );

    final Uint8List pdfBytes = await pdf.save();
    final fileName = 'AURA_${childName.replaceAll(' ', '_').replaceAll(RegExp(r'[^\w]'), '')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    // Trigger browser download
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();

    html.Url.revokeObjectUrl(url);

    print('PDF download triggered: $fileName');
    return 'Downloaded: $fileName';
  }

  static String _sanitizeForPdf(String text) {
    var result = text;

    final replacements = {
      ''': "'", ''': "'", '"': '"', '"': '"',
      '–': '-', '—': '-', '…': '...', '•': '*', '\u00A0': ' ',
    };

    replacements.forEach((key, value) {
      result = result.replaceAll(key, value);
    });

    result = result.replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), '');
    result = result.replaceAll(RegExp(r' +'), ' ');
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return result.trim();
  }

  static String _formatDate(String date) {
    try {
      if (date.contains('T') || date.contains(' ')) {
        final dt = DateTime.parse(date.split('.')[0]);
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
      return date;
    } catch (e) {
      return date;
    }
  }
}
