import '../../../core/logging/app_logger.dart';
import '../../scanner/document_scanner_service.dart';
import '../document_import_service.dart';

class ScanDocumentUseCase {
  ScanDocumentUseCase({
    required DocumentScannerService scanner,
    required DocumentImportService importer,
  })  : _scanner = scanner,
        _importer = importer;

  final DocumentScannerService _scanner;
  final DocumentImportService _importer;

  /// Returns 1 when a scan was imported, 0 when the user cancelled.
  Future<int> call() async {
    log.i('[scan_use_case] starting');
    final scan = await _scanner.scan();
    if (scan == null) {
      log.i('[scan_use_case] cancelled by user');
      return 0;
    }
    try {
      final doc = await _importer.importBytes(
        bytes: scan.pdfBytes,
        originalName: scan.suggestedName,
        mimeType: 'application/pdf',
        ocrTextOverride: scan.ocrText,
        runOcr: false,
      );
      log.i('[scan_use_case] imported id=${doc.id} '
          'classification=${doc.classification ?? "(none)"}');
      return 1;
    } catch (e, st) {
      log.e('[scan_use_case] import failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}
