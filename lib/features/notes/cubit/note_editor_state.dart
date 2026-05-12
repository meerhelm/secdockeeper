import '../../folders/folder.dart';
import '../note.dart';

class NoteEditorState {
  const NoteEditorState({
    this.note,
    this.folder,
    this.title = '',
    this.body = '',
    this.loading = true,
    this.dirty = false,
    this.saving = false,
    this.popRequested = false,
    this.error,
    this.message,
  });

  final Note? note;
  final Folder? folder;
  final String title;
  final String body;
  final bool loading;
  final bool dirty;
  final bool saving;
  final bool popRequested;
  final String? error;
  final String? message;

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  NoteEditorState copyWith({
    Note? note,
    Folder? folder,
    String? title,
    String? body,
    bool? loading,
    bool? dirty,
    bool? saving,
    bool? popRequested,
    String? error,
    String? message,
    bool clearFolder = false,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return NoteEditorState(
      note: note ?? this.note,
      folder: clearFolder ? null : (folder ?? this.folder),
      title: title ?? this.title,
      body: body ?? this.body,
      loading: loading ?? this.loading,
      dirty: dirty ?? this.dirty,
      saving: saving ?? this.saving,
      popRequested: popRequested ?? this.popRequested,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
