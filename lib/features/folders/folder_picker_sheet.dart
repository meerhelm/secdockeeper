import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/app_scope.dart';
import '../../app/tokens.dart';
import '../../app/widgets/app_field.dart';
import 'cubit/folder_picker_cubit.dart';
import 'cubit/folder_picker_state.dart';
import 'folder.dart';
import 'usecases/assign_document_to_folder.dart';
import 'usecases/create_folder.dart';
import 'usecases/delete_folder.dart';
import 'usecases/list_folders.dart';
import 'usecases/rename_folder.dart';
import 'usecases/watch_folder_changes.dart';

class FolderPickerSheet extends StatefulWidget {
  const FolderPickerSheet({super.key, required this.currentFolderId});

  final int? currentFolderId;

  static Future<void> show(
    BuildContext context,
    int documentId,
    int? currentFolderId,
  ) {
    final services = AppScope.of(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider(
        create: (_) => FolderPickerCubit(
          documentId: documentId,
          listFolders: ListFoldersUseCase(services.folders),
          createFolder: CreateFolderUseCase(services.folders),
          assignDocumentToFolder:
              AssignDocumentToFolderUseCase(services.folders),
          renameFolder: RenameFolderUseCase(services.folders),
          deleteFolder: DeleteFolderUseCase(services.folders),
          watchFolderChanges: WatchFolderChangesUseCase(services.folders),
        ),
        child: FolderPickerSheet(currentFolderId: currentFolderId),
      ),
    );
  }

  @override
  State<FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<FolderPickerSheet> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _showFolderActions(BuildContext context, Folder folder) async {
    final cubit = context.read<FolderPickerCubit>();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete folder'),
              subtitle: const Text(
                  'Documents inside will be moved to "No folder"'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final c = context.c;
    if (action == 'rename') {
      final ctl = TextEditingController(text: folder.name);
      final newName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rename folder'),
          content: TextField(
            controller: ctl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'New name'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: c.fg),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (newName != null &&
          newName.trim().isNotEmpty &&
          newName.trim() != folder.name) {
        await cubit.rename(id: folder.id, newName: newName.trim());
      }
    } else if (action == 'delete') {
      await cubit.delete(folder.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return BlocConsumer<FolderPickerCubit, FolderPickerState>(
      listenWhen: (prev, curr) => prev.popRequested != curr.popRequested,
      listener: (context, state) {
        if (state.popRequested) Navigator.of(context).pop();
      },
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Move to folder',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _FolderRow(
                        icon: Icons.inbox_outlined,
                        title: 'No folder',
                        subtitle: null,
                        selected: widget.currentFolderId == null,
                        onTap: () =>
                            context.read<FolderPickerCubit>().select(null),
                      ),
                      for (final f in state.folders)
                        _FolderRow(
                          icon: Icons.folder_outlined,
                          title: f.name,
                          subtitle: '${f.documentCount} item${f.documentCount == 1 ? "" : "s"}',
                          selected: widget.currentFolderId == f.id,
                          onTap: () => context
                              .read<FolderPickerCubit>()
                              .select(f.id),
                          onLongPress: () => _showFolderActions(context, f),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('CREATE NEW FOLDER', style: AppMono.label(context)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: AppField(
                        controller: _input,
                        hintText: 'Folder name',
                        prefixIcon: Icons.create_new_folder_outlined,
                        onSubmitted: (v) => context
                            .read<FolderPickerCubit>()
                            .createAndAssign(v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: state.busy
                            ? null
                            : () => context
                                .read<FolderPickerCubit>()
                                .createAndAssign(_input.text),
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
                        child: const Text('Create'),
                      ),
                    ),
                  ],
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 10),
                  Text(state.error!,
                      style: TextStyle(color: c.error, fontSize: 12)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: c.border, width: 1),
          ),
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
              child: Icon(
                icon,
                size: 16,
                color: selected ? c.accent : c.fg,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? c.accent : c.fg,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: AppMono.of(
                        context,
                        size: 12,
                        color: c.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 16, color: c.accent),
          ],
        ),
      ),
    );
  }
}
