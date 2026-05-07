import 'dart:io';
import 'dart:typed_data';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/logging/app_logger.dart';
import '../ocr/ocr_service.dart';

class ScannedDocument {
  ScannedDocument({
    required this.pdfBytes,
    required this.suggestedName,
    this.ocrText,
  });

  final Uint8List pdfBytes;
  final String suggestedName;
  final String? ocrText;
}

class DocumentScannerService {
  DocumentScannerService({required OcrService ocr}) : _ocr = ocr;

  final OcrService _ocr;

  Future<ScannedDocument?> scan({int maxPages = 24}) async {
    log.i('[scanner] launching scanner (maxPages=$maxPages)');
    final paths = await CunningDocumentScanner.getPictures(
      noOfPages: maxPages,
      isGalleryImportAllowed: false,
      iosScannerOptions: IosScannerOptions(
        imageFormat: IosImageFormat.jpg,
        jpgCompressionQuality: 0.85,
      ),
    );
    if (paths == null || paths.isEmpty) {
      log.i('[scanner] cancelled — no pages captured');
      return null;
    }
    log.i('[scanner] captured ${paths.length} page(s)');

    final files = paths.map(File.new).toList(growable: false);
    try {
      final pdf = pw.Document();
      final ocrPages = <String>[];
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final bytes = await f.readAsBytes();
        final image = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(
              image.width!.toDouble(),
              image.height!.toDouble(),
            ),
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
          ),
        );
        // Each scanned page is a JPEG, which OcrService can process —
        // the standard import path can't OCR PDFs (roadmap #26), so we do it
        // here while we still have per-page images.
        final pageText = await _ocr.recognize(f, mimeType: 'image/jpeg');
        log.d('[scanner] page ${i + 1}/${files.length}: '
            '${bytes.length}B image, ocr=${pageText?.length ?? 0} chars');
        if (pageText != null && pageText.isNotEmpty) ocrPages.add(pageText);
      }
      final pdfBytes = await pdf.save();
      final ocrText = ocrPages.isEmpty ? null : ocrPages.join('\n\n');
      log.i('[scanner] assembled PDF: ${pdfBytes.length}B, '
          'ocrPages=${ocrPages.length}, ocrChars=${ocrText?.length ?? 0}');
      return ScannedDocument(
        pdfBytes: pdfBytes,
        suggestedName: _suggestName(),
        ocrText: ocrText,
      );
    } catch (e, st) {
      log.e('[scanner] scan failed', error: e, stackTrace: st);
      rethrow;
    } finally {
      for (final f in files) {
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    }
  }

  String _suggestName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return 'Scan-$stamp.pdf';
  }
}
