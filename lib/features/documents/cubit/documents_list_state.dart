import '../../folders/folder.dart';
import '../../notes/note.dart';
import '../../tags/tag.dart';
import '../document.dart';
import '../folder_scope.dart';

enum ListMode { documents, notes }

class DocumentsListState {
  const DocumentsListState({
    this.mode = ListMode.documents,
    this.documents = const [],
    this.notes = const [],
    this.folders = const [],
    this.allTags = const [],
    this.query = '',
    this.activeTagIds = const {},
    this.folderScope = const FolderScope.all(),
    this.busy = false,
    this.error,
    this.message,
    this.loadingDocuments = true,
    this.loadingNotes = true,
  });

  final ListMode mode;
  final List<Document> documents;
  final List<Note> notes;
  final List<Folder> folders;
  final List<Tag> allTags;
  final String query;
  final Set<int> activeTagIds;
  final FolderScope folderScope;
  final bool busy;
  final String? error;
  final String? message;
  final bool loadingDocuments;
  final bool loadingNotes;

  bool get isNotesMode => mode == ListMode.notes;
  bool get isLoadingActive =>
      isNotesMode ? loadingNotes : loadingDocuments;

  DocumentsListState copyWith({
    ListMode? mode,
    List<Document>? documents,
    List<Note>? notes,
    List<Folder>? folders,
    List<Tag>? allTags,
    String? query,
    Set<int>? activeTagIds,
    FolderScope? folderScope,
    bool? busy,
    String? error,
    String? message,
    bool? loadingDocuments,
    bool? loadingNotes,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return DocumentsListState(
      mode: mode ?? this.mode,
      documents: documents ?? this.documents,
      notes: notes ?? this.notes,
      folders: folders ?? this.folders,
      allTags: allTags ?? this.allTags,
      query: query ?? this.query,
      activeTagIds: activeTagIds ?? this.activeTagIds,
      folderScope: folderScope ?? this.folderScope,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
      loadingDocuments: loadingDocuments ?? this.loadingDocuments,
      loadingNotes: loadingNotes ?? this.loadingNotes,
    );
  }
}
