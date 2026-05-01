import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../usecases/assign_hidden_tag.dart';
import '../usecases/list_hidden_tags_for_document.dart';
import '../usecases/remove_hidden_tag.dart';
import '../usecases/watch_hidden_tag_changes.dart';
import 'hidden_tags_state.dart';

class HiddenTagsCubit extends Cubit<HiddenTagsState> {
  HiddenTagsCubit({
    required this.documentId,
    required ListHiddenTagsForDocumentUseCase listHiddenTags,
    required AssignHiddenTagUseCase assignHiddenTag,
    required RemoveHiddenTagUseCase removeHiddenTag,
    required WatchHiddenTagChangesUseCase watchHiddenTagChanges,
  })  : _listHiddenTags = listHiddenTags,
        _assignHiddenTag = assignHiddenTag,
        _removeHiddenTag = removeHiddenTag,
        super(const HiddenTagsState()) {
    _sub = watchHiddenTagChanges().listen((_) => _refresh());
    _refresh();
  }

  final int documentId;
  final ListHiddenTagsForDocumentUseCase _listHiddenTags;
  final AssignHiddenTagUseCase _assignHiddenTag;
  final RemoveHiddenTagUseCase _removeHiddenTag;

  late final StreamSubscription<void> _sub;

  Future<void> _refresh() async {
    final names = await _listHiddenTags(documentId);
    if (!isClosed) emit(state.copyWith(names: names));
  }

  Future<void> add(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _assignHiddenTag(documentId: documentId, name: trimmed);
      if (!isClosed) emit(state.copyWith(busy: false));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Failed: $e'));
      }
    }
  }

  Future<void> remove(String name) async {
    try {
      await _removeHiddenTag(documentId: documentId, name: name);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(error: 'Failed: $e'));
    }
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
