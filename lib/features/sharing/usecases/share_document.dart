import '../../documents/document.dart';
import '../share_service.dart';

class ShareDocumentUseCase {
  ShareDocumentUseCase(this._share);

  final ShareService _share;

  Future<void> call(Document document) async {
    final export = await _share.exportDocument(document);
    await _share.shareViaSystem(export);
  }
}
