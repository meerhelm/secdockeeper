import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import 'folder.dart';

class FolderPickerSheet extends StatefulWidget {
  const FolderPickerSheet({
    super.key,
    required this.documentId,
    required this.currentFolderId,
  });

  final int documentId;
  final int? currentFolderId;

  static Future<void> show(BuildContext context, int documentId, int? currentFolderId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => FolderPickerSheet(
        documentId: documentId,
        currentFolderId: currentFolderId,
      ),
    );
  }

  @override
  State<FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<FolderPickerSheet> {
  final _input = TextEditingController();
  Future<List<Folder>>? _folders;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _folders ??= AppScope.of(context).folders.listAll();
  }

  void _refresh() {
    setState(() => _folders = AppScope.of(context).folders.listAll());
  }

  Future<void> _create() async {
    final name = _input.text.trim();
    if (name.isEmpty) return;
    final services = AppScope.of(context);
    final folder = await services.folders.create(name);
    await services.folders.assignDocument(widget.documentId, folder.id);
    _input.clear();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _select(int? folderId) async {
    await AppScope.of(context).folders.assignDocument(widget.documentId, folderId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Move to folder', style: t.titleLarge),
            const SizedBox(height: 12),
            FutureBuilder<List<Folder>>(
              future: _folders,
              builder: (context, snap) {
                final list = snap.data;
                if (list == null) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _FolderTile(
                        icon: Icons.inbox_outlined,
                        title: 'No folder',
                        selected: widget.currentFolderId == null,
                        onTap: () => _select(null),
                      ),
                      for (final f in list)
                        _FolderTile(
                          icon: Icons.folder_outlined,
                          title: f.name,
                          subtitle: '${f.documentCount} item${f.documentCount == 1 ? "" : "s"}',
                          selected: widget.currentFolderId == f.id,
                          onTap: () => _select(f.id),
                          onLongPress: () => _showFolderActions(f),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text('Create new folder',
                style: t.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: scheme.onSurfaceVariant,
                )),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(
                      hintText: 'Folder name',
                      prefixIcon: Icon(Icons.create_new_folder_outlined),
                    ),
                    onSubmitted: (_) => _create(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _create, child: const Text('Create')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFolderActions(Folder folder) async {
    final services = AppScope.of(context);
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
              subtitle: const Text('Documents inside will be moved to "No folder"'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (newName != null && newName.trim().isNotEmpty && newName.trim() != folder.name) {
        await services.folders.rename(folder.id, newName.trim());
      }
    } else if (action == 'delete') {
      await services.folders.delete(folder.id);
    }
    _refresh();
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.icon,
    required this.title,
    this.subtitle,
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon,
                    color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check, color: scheme.onPrimaryContainer, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
