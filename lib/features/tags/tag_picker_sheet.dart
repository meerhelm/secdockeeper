import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/app_scope.dart';
import '../../app/tokens.dart';
import '../../app/widgets/app_field.dart';
import 'cubit/tag_picker_cubit.dart';
import 'cubit/tag_picker_state.dart';
import 'usecases/assign_tag.dart';
import 'usecases/list_all_tags.dart';
import 'usecases/list_tags_for_document.dart';
import 'usecases/unassign_tag.dart';
import 'usecases/upsert_tag.dart';
import 'usecases/watch_tag_changes.dart';

class TagPickerSheet extends StatefulWidget {
  const TagPickerSheet({super.key});

  static Future<void> show(BuildContext context, int documentId) {
    final services = AppScope.of(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider(
        create: (_) => TagPickerCubit(
          documentId: documentId,
          listAllTags: ListAllTagsUseCase(services.tags),
          listTagsForDocument: ListTagsForDocumentUseCase(services.tags),
          upsertTag: UpsertTagUseCase(services.tags),
          assignTag: AssignTagUseCase(services.tags),
          unassignTag: UnassignTagUseCase(services.tags),
          watchTagChanges: WatchTagChangesUseCase(services.tags),
        ),
        child: const TagPickerSheet(),
      ),
    );
  }

  @override
  State<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<TagPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return BlocBuilder<TagPickerCubit, TagPickerState>(
      builder: (context, state) {
        if (_search.text != state.query) {
          _search.value = TextEditingValue(
            text: state.query,
            selection: TextSelection.collapsed(offset: state.query.length),
          );
        }
        final query = state.query.trim().toLowerCase();
        final filtered = query.isEmpty
            ? state.allTags
            : state.allTags
                .where((t) => t.name.toLowerCase().contains(query))
                .toList();
        final showCreate = query.isNotEmpty &&
            !state.allTags.any((t) => t.name.toLowerCase() == query);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 4,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tags',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${state.assignedIds.length} ASSIGNED',
                      style: AppMono.label(context, size: 10).copyWith(color: c.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _search,
                  hintText: 'Search or create tag',
                  prefixIcon: Icons.search,
                  onChanged: (v) => context.read<TagPickerCubit>().setQuery(v),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) => context.read<TagPickerCubit>().createAndAssign(v),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (showCreate)
                        _CreateTagRow(query: state.query),
                      ...filtered.map((t) {
                        final assigned = state.assignedIds.contains(t.id);
                        return _TagCheckRow(
                          name: t.name,
                          checked: assigned,
                          onToggle: () => context.read<TagPickerCubit>().toggleAssign(
                                tagId: t.id,
                                assign: !assigned,
                              ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: c.accent,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreateTagRow extends StatelessWidget {
  const _CreateTagRow({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.accentSoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => context.read<TagPickerCubit>().createAndAssign(query),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add, size: 18, color: c.accentFg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create "${query.trim()}"',
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'New tag · will assign to this document',
                      style: AppMono.of(context, size: 11, color: c.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.subdirectory_arrow_left,
                  size: 16, color: c.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagCheckRow extends StatelessWidget {
  const _TagCheckRow({
    required this.name,
    required this.checked,
    required this.onToggle,
  });

  final String name;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border, width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? c.accent : Colors.transparent,
                border: Border.all(
                  color: checked ? c.accent : c.borderStrong,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: checked
                  ? Icon(Icons.check, size: 14, color: c.accentFg)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: c.fg, fontSize: 14.5, fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
