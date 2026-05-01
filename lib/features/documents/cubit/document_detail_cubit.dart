import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../folders/usecases/get_folder.dart';
import '../../folders/usecases/watch_folder_changes.dart';
import '../../sharing/usecases/share_document.dart';
import '../../tags/usecases/list_tags_for_document.dart';
import '../../tags/usecases/unassign_tag.dart';
import '../../tags/usecases/watch_tag_changes.dart';
import '../usecases/delete_document.dart';
import '../usecases/get_document.dart';
import '../usecases/open_document.dart';
import '../usecases/rename_document.dart';
import '../usecases/watch_document_changes.dart';
import 'document_detail_state.dart';

class DocumentDetailCubit extends Cubit<DocumentDetailState> {
  DocumentDetailCubit({
    required this.documentId,
    required GetDocumentUseCase getDocument,
    required GetFolderUseCase getFolder,
    required ListTagsForDocumentUseCase listTagsForDocument,
    required RenameDocumentUseCase renameDocument,
    required DeleteDocumentUseCase deleteDocument,
    required OpenDocumentUseCase openDocument,
    required ShareDocumentUseCase shareDocument,
    required UnassignTagUseCase unassignTag,
    required WatchDocumentChangesUseCase watchDocumentChanges,
    required WatchFolderChangesUseCase watchFolderChanges,
    required WatchTagChangesUseCase watchTagChanges,
  })  : _getDocument = getDocument,
        _getFolder = getFolder,
        _listTagsForDocument = listTagsForDocument,
        _renameDocument = renameDocument,
        _deleteDocument = deleteDocument,
        _openDocument = openDocument,
        _shareDocument = shareDocument,
        _unassignTag = unassignTag,
        super(const DocumentDetailState()) {
    _docSub = watchDocumentChanges().listen((_) => _reloadDocument());
    _folderSub = watchFolderChanges().listen((_) => _reloadFolder());
    _tagSub = watchTagChanges().listen((_) => _reloadTags());
    _reloadDocument();
    _reloadTags();
  }

  final int documentId;
  final GetDocumentUseCase _getDocument;
  final GetFolderUseCase _getFolder;
  final ListTagsForDocumentUseCase _listTagsForDocument;
  final RenameDocumentUseCase _renameDocument;
  final DeleteDocumentUseCase _deleteDocument;
  final OpenDocumentUseCase _openDocument;
  final ShareDocumentUseCase _shareDocument;
  final UnassignTagUseCase _unassignTag;

  late final StreamSubscription<void> _docSub;
  late final StreamSubscription<void> _folderSub;
  late final StreamSubscription<void> _tagSub;

  Future<void> _reloadDocument() async {
    final doc = await _getDocument(documentId);
    if (isClosed) return;
    if (doc == null) {
      emit(state.copyWith(popRequested: true));
      return;
    }
    emit(state.copyWith(document: doc));
    await _reloadFolder();
  }

  Future<void> _reloadFolder() async {
    final doc = state.document;
    if (doc == null) return;
    final folderId = doc.folderId;
    if (folderId == null) {
      if (!isClosed) emit(state.copyWith(clearFolder: true));
      return;
    }
    final folder = await _getFolder(folderId);
    if (!isClosed) emit(state.copyWith(folder: folder));
  }

  Future<void> _reloadTags() async {
    final tags = await _listTagsForDocument(documentId);
    if (!isClosed) emit(state.copyWith(tags: tags));
  }

  Future<void> rename(String newName) async {
    final doc = state.document;
    if (doc == null) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == doc.originalName) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _renameDocument(id: doc.id, newName: trimmed);
      // change stream → _reloadDocument()
      if (!isClosed) emit(state.copyWith(busy: false));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Rename failed: $e'));
      }
    }
  }

  Future<void> open() async {
    final doc = state.document;
    if (doc == null) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _openDocument(doc);
      if (!isClosed) emit(state.copyWith(busy: false));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Failed to open: $e'));
      }
    }
  }

  Future<void> share() async {
    final doc = state.document;
    if (doc == null) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _shareDocument(doc);
      if (!isClosed) emit(state.copyWith(busy: false));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Share failed: $e'));
      }
    }
  }

  Future<void> delete() async {
    final doc = state.document;
    if (doc == null) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _deleteDocument(doc);
      if (!isClosed) emit(state.copyWith(busy: false, popRequested: true));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Delete failed: $e'));
      }
    }
  }

  Future<void> unassignTag(int tagId) async {
    await _unassignTag(documentId: documentId, tagId: tagId);
    // change stream → _reloadTags()
  }

  @override
  Future<void> close() async {
    await _docSub.cancel();
    await _folderSub.cancel();
    await _tagSub.cancel();
    return super.close();
  }
}
