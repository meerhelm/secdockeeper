import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../usecases/assign_tag.dart';
import '../usecases/list_all_tags.dart';
import '../usecases/list_tags_for_document.dart';
import '../usecases/unassign_tag.dart';
import '../usecases/upsert_tag.dart';
import '../usecases/watch_tag_changes.dart';
import 'tag_picker_state.dart';

class TagPickerCubit extends Cubit<TagPickerState> {
  TagPickerCubit({
    required this.documentId,
    required ListAllTagsUseCase listAllTags,
    required ListTagsForDocumentUseCase listTagsForDocument,
    required UpsertTagUseCase upsertTag,
    required AssignTagUseCase assignTag,
    required UnassignTagUseCase unassignTag,
    required WatchTagChangesUseCase watchTagChanges,
  })  : _listAllTags = listAllTags,
        _listTagsForDocument = listTagsForDocument,
        _upsertTag = upsertTag,
        _assignTag = assignTag,
        _unassignTag = unassignTag,
        super(const TagPickerState()) {
    _sub = watchTagChanges().listen((_) => _refresh());
    _refresh();
  }

  final int documentId;
  final ListAllTagsUseCase _listAllTags;
  final ListTagsForDocumentUseCase _listTagsForDocument;
  final UpsertTagUseCase _upsertTag;
  final AssignTagUseCase _assignTag;
  final UnassignTagUseCase _unassignTag;

  late final StreamSubscription<void> _sub;

  Future<void> _refresh() async {
    final results = await Future.wait([
      _listAllTags(),
      _listTagsForDocument(documentId),
    ]);
    if (isClosed) return;
    final all = results[0];
    final assigned = results[1];
    emit(state.copyWith(
      allTags: all,
      assignedIds: assigned.map((t) => t.id).toSet(),
    ));
  }

  void setQuery(String query) {
    emit(state.copyWith(query: query));
  }

  void clearQuery() {
    emit(state.copyWith(query: ''));
  }

  Future<void> toggleAssign({required int tagId, required bool assign}) async {
    try {
      if (assign) {
        await _assignTag(documentId: documentId, tagId: tagId);
      } else {
        await _unassignTag(documentId: documentId, tagId: tagId);
      }
      // change stream → _refresh()
    } catch (e) {
      if (!isClosed) emit(state.copyWith(error: 'Failed: $e'));
    }
  }

  Future<void> createAndAssign(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final tag = await _upsertTag(trimmed);
      await _assignTag(documentId: documentId, tagId: tag.id);
      if (!isClosed) emit(state.copyWith(busy: false, query: ''));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Failed: $e'));
      }
    }
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
