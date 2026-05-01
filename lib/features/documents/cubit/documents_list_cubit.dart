import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../backup/usecases/export_backup.dart';
import '../../folders/folder.dart';
import '../../folders/usecases/create_folder.dart';
import '../../folders/usecases/list_folders.dart';
import '../../folders/usecases/watch_folder_changes.dart';
import '../../sharing/usecases/import_shared_package.dart';
import '../../tags/usecases/list_all_tags.dart';
import '../../vault/usecases/lock_vault.dart';
import '../folder_scope.dart';
import '../usecases/import_files.dart';
import '../usecases/search_documents.dart';
import '../usecases/watch_document_changes.dart';
import 'documents_list_state.dart';

class DocumentsListCubit extends Cubit<DocumentsListState> {
  DocumentsListCubit({
    required SearchDocumentsUseCase searchDocuments,
    required ListFoldersUseCase listFolders,
    required ListAllTagsUseCase listAllTags,
    required ImportFilesUseCase importFiles,
    required ImportSharedPackageUseCase importSharedPackage,
    required ExportBackupUseCase exportBackup,
    required LockVaultUseCase lockVault,
    required CreateFolderUseCase createFolder,
    required WatchDocumentChangesUseCase watchDocumentChanges,
    required WatchFolderChangesUseCase watchFolderChanges,
  })  : _searchDocuments = searchDocuments,
        _listFolders = listFolders,
        _listAllTags = listAllTags,
        _importFiles = importFiles,
        _importSharedPackage = importSharedPackage,
        _exportBackup = exportBackup,
        _lockVault = lockVault,
        _createFolder = createFolder,
        super(const DocumentsListState()) {
    _docSub = watchDocumentChanges().listen((_) => _refreshDocuments());
    _folderSub = watchFolderChanges().listen((_) => _refreshFolders());
    _refreshDocuments();
    _refreshFolders();
    _loadAllTags();
  }

  final SearchDocumentsUseCase _searchDocuments;
  final ListFoldersUseCase _listFolders;
  final ListAllTagsUseCase _listAllTags;
  final ImportFilesUseCase _importFiles;
  final ImportSharedPackageUseCase _importSharedPackage;
  final ExportBackupUseCase _exportBackup;
  final LockVaultUseCase _lockVault;
  final CreateFolderUseCase _createFolder;

  late final StreamSubscription<void> _docSub;
  late final StreamSubscription<void> _folderSub;

  void setQuery(String query) {
    emit(state.copyWith(query: query));
    _refreshDocuments();
  }

  void clearQuery() {
    emit(state.copyWith(query: ''));
    _refreshDocuments();
  }

  void setFolderScope(FolderScope scope) {
    emit(state.copyWith(folderScope: scope));
    _refreshDocuments();
  }

  void toggleTagFilter(int tagId) {
    final next = Set<int>.from(state.activeTagIds);
    if (!next.add(tagId)) next.remove(tagId);
    emit(state.copyWith(activeTagIds: next));
    _refreshDocuments();
  }

  void clearTagFilter() {
    emit(state.copyWith(activeTagIds: const {}));
    _refreshDocuments();
  }

  Future<void> _loadAllTags() async {
    final tags = await _listAllTags();
    if (!isClosed) emit(state.copyWith(allTags: tags));
  }

  Future<void> refreshAllTags() => _loadAllTags();

  Future<void> _refreshDocuments() async {
    final s = state;
    final docs = await _searchDocuments(
      query: s.query.isEmpty ? null : s.query,
      tagIds: s.activeTagIds.isEmpty ? null : s.activeTagIds.toList(),
      folderId: s.folderScope.specificId,
      onlyUnassignedFolder: s.folderScope.isUnassigned,
    );
    if (!isClosed) {
      emit(state.copyWith(documents: docs, loadingDocuments: false));
    }
  }

  Future<void> _refreshFolders() async {
    final folders = await _listFolders();
    if (!isClosed) emit(state.copyWith(folders: folders));
  }

  Future<void> importFiles(List<ImportFileInput> files) async {
    if (files.isEmpty) return;
    emit(state.copyWith(busy: true, clearError: true, clearMessage: true));
    try {
      final count = await _importFiles(files);
      if (!isClosed) {
        emit(state.copyWith(
          busy: false,
          message: 'Imported $count file(s)',
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Import failed: $e'));
      }
    }
  }

  Future<void> importSharedPackage({
    required File blobFile,
    required File keyFile,
  }) async {
    emit(state.copyWith(busy: true, clearError: true, clearMessage: true));
    try {
      await _importSharedPackage(blobFile: blobFile, keyFile: keyFile);
      if (!isClosed) {
        emit(state.copyWith(
          busy: false,
          message: 'Shared document imported',
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Import failed: $e'));
      }
    }
  }

  Future<void> exportBackup() async {
    emit(state.copyWith(busy: true, clearError: true, clearMessage: true));
    try {
      final archive = await _exportBackup();
      if (!isClosed) {
        emit(state.copyWith(
          busy: false,
          message: 'Backup ready: ${archive.file.path.split('/').last}',
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Backup failed: $e'));
      }
    }
  }

  Future<void> lock() async {
    await _lockVault();
    // Vault state changes → router redirects → cubit closes.
  }

  Future<Folder> createFolder(String name) async {
    return _createFolder(name);
  }

  @override
  Future<void> close() async {
    await _docSub.cancel();
    await _folderSub.cancel();
    return super.close();
  }
}
