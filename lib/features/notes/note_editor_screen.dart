import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../app/widgets/icon_chip_button.dart';
import '../folders/folder_picker_sheet.dart';
import 'cubit/note_editor_cubit.dart';
import 'cubit/note_editor_state.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleCtl = TextEditingController();
  final _bodyCtl = TextEditingController();
  final _bodyFocus = FocusNode();
  bool _hydrated = false;

  @override
  void dispose() {
    _titleCtl.dispose();
    _bodyCtl.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _hydrateOnce(NoteEditorState state) {
    if (_hydrated || state.note == null) return;
    _titleCtl.text = state.title;
    _bodyCtl.text = state.body;
    _hydrated = true;
    if (state.title.isEmpty && state.body.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bodyFocus.requestFocus();
      });
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final c = context.c;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note'),
        content: Text(
          'This note will be permanently removed from this vault.',
          style: TextStyle(color: c.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: c.fg),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.error,
              side: BorderSide(color: c.error, width: 1),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final messenger = ScaffoldMessenger.of(context);

    return BlocConsumer<NoteEditorCubit, NoteEditorState>(
      listenWhen: (prev, curr) =>
          prev.popRequested != curr.popRequested ||
          prev.error != curr.error,
      listener: (context, state) {
        if (state.popRequested) {
          context.pop();
          return;
        }
        if (state.error != null) {
          messenger.showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      builder: (context, state) {
        _hydrateOnce(state);
        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: Column(
              children: [
                _EditorAppBar(
                  saving: state.saving,
                  dirty: state.dirty,
                  hasNote: state.note != null,
                  onBack: () async {
                    await context.read<NoteEditorCubit>().save();
                    if (!context.mounted) return;
                    context.pop();
                  },
                  onDelete: state.note == null
                      ? null
                      : () async {
                          final ok = await _confirmDelete(context);
                          if (!context.mounted || !ok) return;
                          await context.read<NoteEditorCubit>().delete();
                        },
                ),
                if (state.loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FolderRow(
                            folderName: state.folder?.name,
                            onTap: state.note == null
                                ? null
                                : () => FolderPickerSheet.showForNote(
                                      context,
                                      state.note!.id,
                                      state.note!.folderId,
                                    ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _titleCtl,
                            onChanged:
                                context.read<NoteEditorCubit>().setTitle,
                            cursorColor: c.accent,
                            maxLines: 2,
                            minLines: 1,
                            style: TextStyle(
                              color: c.fg,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              border: InputBorder.none,
                              hintText: 'Title',
                              hintStyle: TextStyle(
                                color: c.muted2,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 1,
                            color: c.border,
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: TextField(
                              controller: _bodyCtl,
                              focusNode: _bodyFocus,
                              onChanged:
                                  context.read<NoteEditorCubit>().setBody,
                              cursorColor: c.accent,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              keyboardType: TextInputType.multiline,
                              style: TextStyle(
                                color: c.fg,
                                fontSize: 15,
                                height: 1.5,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                border: InputBorder.none,
                                hintText: 'Start writing…',
                                hintStyle: TextStyle(
                                  color: c.muted2,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.folderName, required this.onTap});

  final String? folderName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final assigned = folderName != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              assigned ? Icons.folder_outlined : Icons.inbox_outlined,
              size: 14,
              color: assigned ? c.accent : c.muted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                folderName ?? 'No folder',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: assigned ? c.fg : c.muted,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.unfold_more, size: 12, color: c.muted2),
          ],
        ),
      ),
    );
  }
}

class _EditorAppBar extends StatelessWidget {
  const _EditorAppBar({
    required this.saving,
    required this.dirty,
    required this.hasNote,
    required this.onBack,
    required this.onDelete,
  });

  final bool saving;
  final bool dirty;
  final bool hasNote;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final label = saving
        ? 'SAVING…'
        : dirty
            ? 'UNSAVED'
            : 'SAVED';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          IconChipButton(
            icon: Icons.arrow_back_ios_new,
            onTap: onBack,
            ghost: true,
          ),
          const Spacer(),
          Text(label, style: AppMono.label(context, size: 10)),
          const SizedBox(width: 4),
          if (saving)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: c.muted,
              ),
            )
          else
            Icon(
              dirty ? Icons.circle : Icons.check_circle,
              size: 10,
              color: dirty ? c.warn : c.accent,
            ),
          const SizedBox(width: 8),
          if (hasNote)
            IconChipButton(
              icon: Icons.delete_outline,
              onTap: saving ? null : onDelete,
              ghost: true,
              tooltip: 'Delete',
            ),
        ],
      ),
    );
  }
}
