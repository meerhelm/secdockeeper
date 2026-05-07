import 'dart:io';

import '../../documents/document.dart';
import '../share_service.dart';

class ImportSharedPackageUseCase {
  ImportSharedPackageUseCase(this._share);

  final ShareService _share;

  Future<Document> call({required File blobFile, required File keyFile}) =>
      _share.importPackage(blobFile: blobFile, keyFile: keyFile);
}
