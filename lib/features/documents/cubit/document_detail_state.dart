import '../../folders/folder.dart';
import '../../tags/tag.dart';
import '../document.dart';

class DocumentDetailState {
  const DocumentDetailState({
    this.document,
    this.folder,
    this.tags = const [],
    this.busy = false,
    this.error,
    this.message,
    this.popRequested = false,
  });

  final Document? document;
  final Folder? folder;
  final List<Tag> tags;
  final bool busy;
  final String? error;
  final String? message;

  /// Set after a successful delete so the screen knows to pop back.
  final bool popRequested;

  DocumentDetailState copyWith({
    Document? document,
    Folder? folder,
    List<Tag>? tags,
    bool? busy,
    String? error,
    String? message,
    bool? popRequested,
    bool clearError = false,
    bool clearMessage = false,
    bool clearFolder = false,
  }) {
    return DocumentDetailState(
      document: document ?? this.document,
      folder: clearFolder ? null : (folder ?? this.folder),
      tags: tags ?? this.tags,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
      popRequested: popRequested ?? this.popRequested,
    );
  }
}
