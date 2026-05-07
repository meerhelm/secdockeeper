import 'dart:io';
import 'dart:typed_data';

import '../document_import_service.dart';

typedef ImportFileInput = ({String name, Uint8List? bytes, String? path});

class ImportFilesUseCase {
  ImportFilesUseCase(this._importer);

  final DocumentImportService _importer;

  Future<int> call(List<ImportFileInput> files) async {
    var imported = 0;
    for (final f in files) {
      final bytes = f.bytes;
      if (bytes != null) {
        await _importer.importBytes(bytes: bytes, originalName: f.name);
      } else if (f.path != null) {
        await _importer.importFile(File(f.path!));
      } else {
        continue;
      }
      imported++;
    }
    return imported;
  }
}
