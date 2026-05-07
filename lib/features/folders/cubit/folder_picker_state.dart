import '../folder.dart';

class FolderPickerState {
  const FolderPickerState({
    this.folders = const [],
    this.busy = false,
    this.error,
    this.popRequested = false,
  });

  final List<Folder> folders;
  final bool busy;
  final String? error;
  final bool popRequested;

  FolderPickerState copyWith({
    List<Folder>? folders,
    bool? busy,
    String? error,
    bool? popRequested,
    bool clearError = false,
  }) {
    return FolderPickerState(
      folders: folders ?? this.folders,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      popRequested: popRequested ?? this.popRequested,
    );
  }
}
