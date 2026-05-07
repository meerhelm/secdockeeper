import '../document.dart';
import '../document_open_service.dart';

class OpenDocumentUseCase {
  OpenDocumentUseCase(this._opener);

  final DocumentOpenService _opener;

  Future<void> call(Document document) async {
    await _opener.open(document);
  }
}
