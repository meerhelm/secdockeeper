import '../tag.dart';

class TagPickerState {
  const TagPickerState({
    this.allTags = const [],
    this.assignedIds = const {},
    this.query = '',
    this.busy = false,
    this.error,
  });

  final List<Tag> allTags;
  final Set<int> assignedIds;
  final String query;
  final bool busy;
  final String? error;

  TagPickerState copyWith({
    List<Tag>? allTags,
    Set<int>? assignedIds,
    String? query,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return TagPickerState(
      allTags: allTags ?? this.allTags,
      assignedIds: assignedIds ?? this.assignedIds,
      query: query ?? this.query,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
