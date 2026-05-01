import '../../folders/folder.dart';
import '../../tags/tag.dart';
import '../document.dart';
import '../folder_scope.dart';

class DocumentsListState {
  const DocumentsListState({
    this.documents = const [],
    this.folders = const [],
    this.allTags = const [],
    this.query = '',
    this.activeTagIds = const {},
    this.folderScope = const FolderScope.all(),
    this.busy = false,
    this.error,
    this.message,
    this.loadingDocuments = true,
  });

  final List<Document> documents;
  final List<Folder> folders;
  final List<Tag> allTags;
  final String query;
  final Set<int> activeTagIds;
  final FolderScope folderScope;
  final bool busy;
  final String? error;
  final String? message;
  final bool loadingDocuments;

  DocumentsListState copyWith({
    List<Document>? documents,
    List<Folder>? folders,
    List<Tag>? allTags,
    String? query,
    Set<int>? activeTagIds,
    FolderScope? folderScope,
    bool? busy,
    String? error,
    String? message,
    bool? loadingDocuments,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return DocumentsListState(
      documents: documents ?? this.documents,
      folders: folders ?? this.folders,
      allTags: allTags ?? this.allTags,
      query: query ?? this.query,
      activeTagIds: activeTagIds ?? this.activeTagIds,
      folderScope: folderScope ?? this.folderScope,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
      loadingDocuments: loadingDocuments ?? this.loadingDocuments,
    );
  }
}
