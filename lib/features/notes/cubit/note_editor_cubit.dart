import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../folders/usecases/get_folder.dart';
import '../../folders/usecases/watch_folder_changes.dart';
import '../usecases/delete_note.dart';
import '../usecases/get_note.dart';
import '../usecases/save_note.dart';
import 'note_editor_state.dart';

class NoteEditorCubit extends Cubit<NoteEditorState> {
  NoteEditorCubit({
    required this.noteId,
    required GetNoteUseCase getNote,
    required SaveNoteUseCase saveNote,
    required DeleteNoteUseCase deleteNote,
    required GetFolderUseCase getFolder,
    required WatchFolderChangesUseCase watchFolderChanges,
  })  : _getNote = getNote,
        _saveNote = saveNote,
        _deleteNote = deleteNote,
        _getFolder = getFolder,
        super(const NoteEditorState()) {
    _folderSub = watchFolderChanges().listen((_) => _reloadFromDb());
    _load();
  }

  final int noteId;
  final GetNoteUseCase _getNote;
  final SaveNoteUseCase _saveNote;
  final DeleteNoteUseCase _deleteNote;
  final GetFolderUseCase _getFolder;

  late final StreamSubscription<void> _folderSub;
  Timer? _autosaveTimer;
  static const _autosaveDelay = Duration(milliseconds: 600);

  Future<void> _load() async {
    final note = await _getNote(noteId);
    if (isClosed) return;
    if (note == null) {
      emit(state.copyWith(popRequested: true));
      return;
    }
    emit(state.copyWith(
      note: note,
      title: note.title,
      body: note.body,
      loading: false,
      dirty: false,
    ));
    await _reloadFolder();
  }

  Future<void> _reloadFromDb() async {
    if (state.note == null) return;
    final note = await _getNote(noteId);
    if (isClosed || note == null) return;
    // Preserve the user's unsaved edits; just refresh folder linkage.
    emit(state.copyWith(note: note));
    await _reloadFolder();
  }

  Future<void> _reloadFolder() async {
    final note = state.note;
    if (note == null) return;
    final id = note.folderId;
    if (id == null) {
      if (!isClosed) emit(state.copyWith(clearFolder: true));
      return;
    }
    final folder = await _getFolder(id);
    if (!isClosed) emit(state.copyWith(folder: folder));
  }

  void setTitle(String value) {
    if (value == state.title) return;
    emit(state.copyWith(title: value, dirty: true));
    _scheduleAutosave();
  }

  void setBody(String value) {
    if (value == state.body) return;
    emit(state.copyWith(body: value, dirty: true));
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, () {
      save();
    });
  }

  Future<void> save() async {
    final s = state;
    if (s.note == null) return;
    if (!s.dirty) return;
    _autosaveTimer?.cancel();
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _saveNote(id: s.note!.id, title: s.title, body: s.body);
      if (!isClosed) {
        emit(state.copyWith(saving: false, dirty: false));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(saving: false, error: 'Save failed: $e'));
      }
    }
  }

  Future<void> delete() async {
    final s = state;
    if (s.note == null) return;
    _autosaveTimer?.cancel();
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _deleteNote(s.note!.id);
      if (!isClosed) {
        emit(state.copyWith(saving: false, popRequested: true));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(saving: false, error: 'Delete failed: $e'));
      }
    }
  }

  @override
  Future<void> close() async {
    _autosaveTimer?.cancel();
    await _folderSub.cancel();
    if (state.dirty && state.note != null) {
      try {
        await _saveNote(
          id: state.note!.id,
          title: state.title,
          body: state.body,
        );
      } catch (_) {}
    }
    return super.close();
  }
}
