import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../usecases/create_folder.dart';
import '../usecases/delete_folder.dart';
import '../usecases/list_folders.dart';
import '../usecases/rename_folder.dart';
import '../usecases/watch_folder_changes.dart';
import 'folder_picker_state.dart';

typedef AssignFolderCallback = Future<void> Function(int? folderId);

class FolderPickerCubit extends Cubit<FolderPickerState> {
  FolderPickerCubit({
    required AssignFolderCallback onAssign,
    required ListFoldersUseCase listFolders,
    required CreateFolderUseCase createFolder,
    required RenameFolderUseCase renameFolder,
    required DeleteFolderUseCase deleteFolder,
    required WatchFolderChangesUseCase watchFolderChanges,
  })  : _onAssign = onAssign,
        _listFolders = listFolders,
        _createFolder = createFolder,
        _renameFolder = renameFolder,
        _deleteFolder = deleteFolder,
        super(const FolderPickerState()) {
    _sub = watchFolderChanges().listen((_) => _refresh());
    _refresh();
  }

  final AssignFolderCallback _onAssign;
  final ListFoldersUseCase _listFolders;
  final CreateFolderUseCase _createFolder;
  final RenameFolderUseCase _renameFolder;
  final DeleteFolderUseCase _deleteFolder;

  late final StreamSubscription<void> _sub;

  Future<void> _refresh() async {
    final folders = await _listFolders();
    if (!isClosed) emit(state.copyWith(folders: folders));
  }

  Future<void> select(int? folderId) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _onAssign(folderId);
      if (!isClosed) emit(state.copyWith(busy: false, popRequested: true));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Failed: $e'));
      }
    }
  }

  Future<void> createAndAssign(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final folder = await _createFolder(trimmed);
      await _onAssign(folder.id);
      if (!isClosed) emit(state.copyWith(busy: false, popRequested: true));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Failed: $e'));
      }
    }
  }

  Future<void> rename({required int id, required String newName}) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    try {
      await _renameFolder(id: id, newName: trimmed);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(error: 'Rename failed: $e'));
    }
  }

  Future<void> delete(int id) async {
    try {
      await _deleteFolder(id);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(error: 'Delete failed: $e'));
    }
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
