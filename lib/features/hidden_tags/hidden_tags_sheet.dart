import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/app_scope.dart';
import '../../app/tokens.dart';
import '../../app/widgets/app_field.dart';
import '../../app/widgets/warn_banner.dart';
import 'cubit/hidden_tags_cubit.dart';
import 'cubit/hidden_tags_state.dart';
import 'usecases/assign_hidden_tag.dart';
import 'usecases/list_hidden_tags_for_document.dart';
import 'usecases/remove_hidden_tag.dart';
import 'usecases/watch_hidden_tag_changes.dart';

class HiddenTagsSheet extends StatefulWidget {
  const HiddenTagsSheet({super.key});

  static Future<void> show(BuildContext context, int documentId) {
    final services = AppScope.of(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider(
        create: (_) => HiddenTagsCubit(
          documentId: documentId,
          listHiddenTags:
              ListHiddenTagsForDocumentUseCase(services.hiddenTags),
          assignHiddenTag: AssignHiddenTagUseCase(services.hiddenTags),
          removeHiddenTag: RemoveHiddenTagUseCase(services.hiddenTags),
          watchHiddenTagChanges:
              WatchHiddenTagChangesUseCase(services.hiddenTags),
        ),
        child: const HiddenTagsSheet(),
      ),
    );
  }

  @override
  State<HiddenTagsSheet> createState() => _HiddenTagsSheetState();
}

class _HiddenTagsSheetState extends State<HiddenTagsSheet> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add(BuildContext context) {
    final name = _input.text.trim();
    if (name.isEmpty) return;
    context.read<HiddenTagsCubit>().add(name);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return BlocBuilder<HiddenTagsCubit, HiddenTagsState>(
      builder: (context, state) {
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
                    Icon(Icons.visibility_off_outlined, size: 18, color: c.fg),
                    const SizedBox(width: 10),
                    Text(
                      'Hidden tags',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tags here are stored as cryptographic hashes. They never appear in the UI '
                  'unless someone types the exact tag name into the search bar.',
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: AppField(
                        controller: _input,
                        hintText: 'Hidden tag name',
                        prefixIcon: Icons.add,
                        autofocus: true,
                        onSubmitted: (_) => _add(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: state.busy ? null : () => _add(context),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${state.names.length} ASSIGNED',
                  style: AppMono.label(context, size: 10),
                ),
                const SizedBox(height: 4),
                if (state.names.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No hidden tags assigned yet.',
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.32,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final n in state.names)
                          _HiddenRow(
                            name: n,
                            onDelete: () =>
                                context.read<HiddenTagsCubit>().remove(n),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                const WarnBanner(
                  title: 'The plaintext is not stored.',
                  body: 'Forget the name and the tag is unrecoverable from this device.',
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

class _HiddenRow extends StatelessWidget {
  const _HiddenRow({required this.name, required this.onDelete});
  final String name;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.tag, size: 16, color: c.fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '#$name',
              style: AppMono.of(
                context,
                size: 13,
                color: c.fg,
                weight: FontWeight.w500,
                letterSpacing: 0.6,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline, color: c.muted),
          ),
        ],
      ),
    );
  }
}
