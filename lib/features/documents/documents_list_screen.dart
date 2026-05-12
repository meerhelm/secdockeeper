import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/tokens.dart';
import '../../app/widgets/app_chip.dart';
import '../../app/widgets/app_search_field.dart';
import '../../app/widgets/badges.dart';
import '../../app/widgets/brand_mark.dart';
import '../../app/widgets/icon_chip_button.dart';
import '../folders/folder.dart';
import '../notes/note.dart';
import '../tags/tag.dart';
import 'cubit/documents_list_cubit.dart';
import 'cubit/documents_list_state.dart';
import 'document.dart';
import 'folder_scope.dart';
import 'usecases/import_files.dart';
import 'widgets/document_thumb.dart';
import '../vault/widgets/change_master_password_dialog.dart';
import '../vault/widgets/destroy_vault_dialog.dart';

class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _showAddSheet() async {
    final cubit = context.read<DocumentsListCubit>();
    final action = await showModalBottomSheet<_AddAction>(
      context: context,
      builder: (_) => const _AddSheet(),
    );
    if (action == null) return;
    switch (action) {
      case _AddAction.scan:
        await cubit.scanDocument();
      case _AddAction.importFile:
        await _pickAndImportFiles(cubit);
      case _AddAction.fromGallery:
        await _pickAndImportFromGallery(cubit);
    }
  }

  Future<void> _pickAndImportFiles(DocumentsListCubit cubit) async {
    final result = await FilePicker.pickFiles(
      withData: true,
      allowMultiple: true,
    );
    if (result == null) return;
    final inputs = <ImportFileInput>[
      for (final f in result.files)
        (name: f.name, bytes: f.bytes, path: f.path),
    ];
    await cubit.importFiles(inputs);
  }

  Future<void> _pickAndImportFromGallery(DocumentsListCubit cubit) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    if (result == null) return;
    final inputs = <ImportFileInput>[
      for (final f in result.files)
        (name: f.name, bytes: f.bytes, path: f.path),
    ];
    await cubit.importFiles(inputs);
  }

  Future<void> _importShared() async {
    final cubit = context.read<DocumentsListCubit>();
    final blobPick = await FilePicker.pickFiles(
      dialogTitle: 'Pick the .sdkblob file',
      type: FileType.any,
    );
    if (blobPick == null || blobPick.files.isEmpty) return;
    final blobPath = blobPick.files.single.path;
    if (blobPath == null) return;

    if (!mounted) return;
    final keyPick = await FilePicker.pickFiles(
      dialogTitle: 'Pick the matching .sdkkey.json file',
      type: FileType.any,
    );
    if (keyPick == null || keyPick.files.isEmpty) return;
    final keyPath = keyPick.files.single.path;
    if (keyPath == null) return;

    await cubit.importSharedPackage(
      blobFile: File(blobPath),
      keyFile: File(keyPath),
    );
  }

  Future<void> _openTagFilter() async {
    final cubit = context.read<DocumentsListCubit>();
    await cubit.refreshAllTags();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => BlocProvider.value(
        value: cubit,
        child: const _TagFilterSheet(),
      ),
    );
  }

  Future<void> _showCreateFolder() async {
    final cubit = context.read<DocumentsListCubit>();
    final ctl = TextEditingController();
    final c = context.c;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder name'),
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      final folder = await cubit.createFolder(name.trim());
      cubit.setFolderScope(FolderScope.specific(folder.id));
    }
  }

  Future<void> _showChangePassword() async {
    final cubit = context.read<DocumentsListCubit>();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (ctx) => const ChangeMasterPasswordDialog(),
    );
    if (newPassword != null) {
      await cubit.changeMasterPassword(newPassword);
    }
  }

  Future<void> _showDestroyVault() async {
    final cubit = context.read<DocumentsListCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const DestroyVaultDialog(),
    );
    if (confirmed == true) {
      await cubit.destroyVault();
    }
  }

  void _openSettings() {
    context.push(AppRoutes.settings);
  }

  void _toggleMode() {
    final cubit = context.read<DocumentsListCubit>();
    final next = cubit.state.isNotesMode
        ? ListMode.documents
        : ListMode.notes;
    cubit.setMode(next);
  }

  Future<void> _createNewNote() async {
    final cubit = context.read<DocumentsListCubit>();
    final note = await cubit.createNote();
    if (!mounted) return;
    await context.push(AppRoutes.noteDetailPath('${note.id}'));
  }

  Future<void> _confirmDeleteNote(Note note) async {
    final c = context.c;
    final cubit = context.read<DocumentsListCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note'),
        content: Text(
          '“${note.displayTitle}” will be permanently removed from this vault.',
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
    if (confirmed == true) {
      await cubit.deleteNote(note.id);
    }
  }

  String _formatTotalSize(List<Document> docs) {
    final bytes = docs.fold<int>(0, (a, b) => a + b.size);
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final messenger = ScaffoldMessenger.of(context);

    return BlocConsumer<DocumentsListCubit, DocumentsListState>(
      listenWhen: (prev, curr) =>
          prev.message != curr.message || prev.error != curr.error,
      listener: (context, state) {
        if (state.message != null) {
          messenger.showSnackBar(_AppSnack(message: state.message!).build(context));
        }
        if (state.error != null) {
          messenger.showSnackBar(_AppSnack(
            message: state.error!,
            error: true,
          ).build(context));
        }
      },
      builder: (context, state) {
        if (_searchCtl.text != state.query) {
          _searchCtl.value = TextEditingValue(
            text: state.query,
            selection: TextSelection.collapsed(offset: state.query.length),
          );
        }
        final hasFilter = state.activeTagIds.isNotEmpty;
        final notesMode = state.isNotesMode;
        final statsLabel = notesMode
            ? '${state.notes.length.toString().padLeft(2, '0')} notes'
            : '${state.documents.length.toString().padLeft(2, '0')} documents · ${_formatTotalSize(state.documents)}';

        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _VaultHeader(
                      notesMode: notesMode,
                      onLock: () => context.read<DocumentsListCubit>().lock(),
                      onToggleMode: _toggleMode,
                      onImportShared: _importShared,
                      onExportBackup: () =>
                          context.read<DocumentsListCubit>().exportBackup(),
                      onChangePassword: _showChangePassword,
                      onSettings: _openSettings,
                      onDestroyVault: _showDestroyVault,
                    )),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: AppSearchField(
                          controller: _searchCtl,
                          hintText: notesMode
                              ? 'Search notes by title…'
                              : 'Search by name, content or hidden tag…',
                          onChanged: (v) => context
                              .read<DocumentsListCubit>()
                              .setQuery(v.trim()),
                          suffix: state.query.isEmpty
                              ? null
                              : InkWell(
                                  onTap: () => context
                                      .read<DocumentsListCubit>()
                                      .clearQuery(),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(Icons.close,
                                        size: 16, color: c.muted),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _Rail(
                        scope: state.folderScope,
                        folders: state.folders,
                        hasFilter: hasFilter,
                        filterCount: state.activeTagIds.length,
                        showFilter: !notesMode,
                        onFilter: _openTagFilter,
                        onSelect: (s) =>
                            context.read<DocumentsListCubit>().setFolderScope(s),
                        onAddFolder: _showCreateFolder,
                      ),
                    ),
                    SliverToBoxAdapter(child: _StatsRow(label: statsLabel)),
                    if (state.isLoadingActive)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (notesMode && state.notes.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyNotesState(hasQuery: state.query.isNotEmpty),
                      )
                    else if (!notesMode && state.documents.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
                    else if (notesMode)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                        sliver: SliverList.separated(
                          itemCount: state.notes.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final note = state.notes[i];
                            return _NoteCard(
                              note: note,
                              onTap: () => context.push(
                                AppRoutes.noteDetailPath('${note.id}'),
                              ),
                              onDelete: () => _confirmDeleteNote(note),
                            );
                          },
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                        sliver: SliverList.separated(
                          itemCount: state.documents.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) =>
                              _DocCard(document: state.documents[i]),
                        ),
                      ),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    onPressed: state.busy
                        ? null
                        : (notesMode ? _createNewNote : _showAddSheet),
                    icon: state.busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: c.accentFg,
                            ),
                          )
                        : const Icon(Icons.add, size: 18),
                    label: Text(notesMode ? 'New note' : 'Add'),
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

class _VaultHeader extends StatelessWidget {
  const _VaultHeader({
    required this.notesMode,
    required this.onLock,
    required this.onToggleMode,
    required this.onImportShared,
    required this.onExportBackup,
    required this.onChangePassword,
    required this.onSettings,
    required this.onDestroyVault,
  });

  final bool notesMode;
  final VoidCallback onLock;
  final VoidCallback onToggleMode;
  final VoidCallback onImportShared;
  final VoidCallback onExportBackup;
  final VoidCallback onChangePassword;
  final VoidCallback onSettings;
  final VoidCallback onDestroyVault;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      child: Row(
        children: [
          const BrandMark(size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notesMode ? 'Notes' : 'Vault',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconChipButton(
            icon: notesMode
                ? Icons.folder_copy_outlined
                : Icons.sticky_note_2_outlined,
            onTap: onToggleMode,
            tooltip: notesMode ? 'Files' : 'Notes',
          ),
          const SizedBox(width: 8),
          IconChipButton(
            icon: Icons.lock_outline,
            onTap: onLock,
            tooltip: 'Lock',
          ),
          const SizedBox(width: 8),
          _OverflowMenu(
            onImportShared: onImportShared,
            onExportBackup: onExportBackup,
            onChangePassword: onChangePassword,
            onSettings: onSettings,
            onDestroyVault: onDestroyVault,
          ),
        ],
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.onImportShared,
    required this.onExportBackup,
    required this.onChangePassword,
    required this.onSettings,
    required this.onDestroyVault,
  });
  final VoidCallback onImportShared;
  final VoidCallback onExportBackup;
  final VoidCallback onChangePassword;
  final VoidCallback onSettings;
  final VoidCallback onDestroyVault;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'import_share') onImportShared();
        if (v == 'export_backup') onExportBackup();
        if (v == 'change_password') onChangePassword();
        if (v == 'settings') onSettings();
        if (v == 'destroy_vault') onDestroyVault();
      },
      offset: const Offset(0, 44),
      tooltip: 'More',
      icon: Icon(Icons.more_horiz, size: 18, color: c.fg),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'import_share',
          child: _MenuItem(
            icon: Icons.upload_outlined,
            title: 'Import shared package',
            sub: '.sdkblob + .sdkkey.json',
          ),
        ),
        PopupMenuItem(
          value: 'export_backup',
          child: _MenuItem(
            icon: Icons.download_outlined,
            title: 'Export full backup',
            sub: 'encrypted .zip · password-protected',
          ),
        ),
        PopupMenuItem(
          value: 'change_password',
          child: _MenuItem(
            icon: Icons.key_outlined,
            title: 'Change master password',
            sub: 're-encrypts all document keys',
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: _MenuItem(
            icon: Icons.tune,
            title: 'Settings',
            sub: 'panic mode and other tunables',
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'destroy_vault',
          child: _MenuItem(
            icon: Icons.delete_forever_outlined,
            title: 'Destroy vault',
            sub: 'wipes every document — irreversible',
            danger: true,
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.sub,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String sub;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final iconColor = danger ? c.error : c.muted;
    final titleColor = danger ? c.error : c.fg;
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: TextStyle(fontSize: 14, color: titleColor)),
            const SizedBox(height: 2),
            Text(sub,
                style: AppMono.of(context, size: 10, color: c.muted)),
          ],
        ),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.scope,
    required this.folders,
    required this.hasFilter,
    required this.filterCount,
    required this.showFilter,
    required this.onFilter,
    required this.onSelect,
    required this.onAddFolder,
  });

  final FolderScope scope;
  final List<Folder> folders;
  final bool hasFilter;
  final int filterCount;
  final bool showFilter;
  final VoidCallback onFilter;
  final ValueChanged<FolderScope> onSelect;
  final VoidCallback onAddFolder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        children: [
          if (showFilter) ...[
            AppChip(
              label: 'Filter',
              count: hasFilter ? filterCount : null,
              selected: hasFilter,
              icon: Icons.tune,
              onTap: onFilter,
            ),
            const SizedBox(width: 8),
          ],
          AppChip(
            label: 'All',
            selected: scope.isAll,
            onTap: () => onSelect(const FolderScope.all()),
          ),
          const SizedBox(width: 8),
          AppChip(
            label: 'No folder',
            selected: scope.isUnassigned,
            onTap: () => onSelect(const FolderScope.unassigned()),
          ),
          for (final f in folders) ...[
            const SizedBox(width: 8),
            AppChip(
              label: f.name,
              count: f.documentCount,
              selected: scope.specificId == f.id,
              onTap: () => onSelect(FolderScope.specific(f.id)),
            ),
          ],
          const SizedBox(width: 8),
          AppDashedChip(label: 'New', onTap: onAddFolder),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppMono.label(context, size: 10),
          ),
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.document});
  final Document document;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            context.push(AppRoutes.documentDetailPath('${document.id}')),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: c.border, width: 1),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              DocumentThumb(mime: document.mimeType, uuid: document.uuid),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      document.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.fg,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.07,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 10, color: c.muted),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '${_formatSize(document.size)} · ${_formatDate(document.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppMono.meta(context),
                          ),
                        ),
                      ],
                    ),
                    if (document.classification != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          ClassBadge(document.classification!),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 16, color: c.muted2),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'today ${pad(d.hour)}:${pad(d.minute)}';
    }
    if (d.year == now.year) {
      return '${pad(d.day)}.${pad(d.month)}';
    }
    return '${d.year}-${pad(d.month)}-${pad(d.day)}';
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onDelete,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: c.border, width: 1),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 16, color: c.muted2),
                ],
              ),
              if (note.preview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 10, color: c.muted),
                  const SizedBox(width: 5),
                  Text(
                    _formatNoteDate(note.updatedAt),
                    style: AppMono.meta(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatNoteDate(DateTime d) {
    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'today ${pad(d.hour)}:${pad(d.minute)}';
    }
    if (d.year == now.year) {
      return '${pad(d.day)}.${pad(d.month)} ${pad(d.hour)}:${pad(d.minute)}';
    }
    return '${d.year}-${pad(d.month)}-${pad(d.day)}';
  }
}

class _EmptyNotesState extends StatelessWidget {
  const _EmptyNotesState({required this.hasQuery});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: c.surface,
              shape: BoxShape.circle,
              border: Border.all(color: c.borderStrong, width: 1),
            ),
            child: Center(
              child: Icon(
                hasQuery
                    ? Icons.search_off
                    : Icons.sticky_note_2_outlined,
                size: 36,
                color: c.muted,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(hasQuery ? 'No notes match' : 'No notes yet',
              style: t.headlineSmall),
          const SizedBox(height: 8),
          Text(
            hasQuery
                ? 'Try a different search term.'
                : 'Tap “New note” to capture a thought. Notes are encrypted at rest with your vault.',
            style: t.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: c.surface,
              shape: BoxShape.circle,
              border: Border.all(color: c.borderStrong, width: 1, style: BorderStyle.solid),
            ),
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.transparent,
                width: 1,
              ),
            ),
            child: CustomPaint(
              painter: _DashedCirclePainter(color: c.borderStrong),
              child: Center(
                child: Icon(
                  Icons.folder_open_outlined,
                  size: 36,
                  color: c.muted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Vault is empty', style: t.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Tap Import to add your first encrypted document. Files never leave this device.',
            style: t.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final radius = size.width / 2 - 1;
    final center = Offset(size.width / 2, size.height / 2);
    const segments = 32;
    for (var i = 0; i < segments; i++) {
      final start = (i * 2) * 3.14159265 / segments;
      final sweep = 1 * 3.14159265 / segments;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}

class _TagFilterSheet extends StatelessWidget {
  const _TagFilterSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return BlocBuilder<DocumentsListCubit, DocumentsListState>(
      builder: (context, state) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filter by tags',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context
                          .read<DocumentsListCubit>()
                          .clearTagFilter(),
                      style: TextButton.styleFrom(foregroundColor: c.muted),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (state.allTags.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No tags yet. Create them on a document.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final Tag t in state.allTags)
                          _CheckRow(
                            label: t.name,
                            checked: state.activeTagIds.contains(t.id),
                            onTap: () => context
                                .read<DocumentsListCubit>()
                                .toggleTagFilter(t.id),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${state.activeTagIds.length} SELECTED · ${state.documents.length} MATCH',
                      style: AppMono.label(context, size: 10),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: c.accent),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
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
                label,
                style: TextStyle(color: c.fg, fontSize: 14.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AddAction { scan, importFile, fromGallery }

class _AddSheet extends StatelessWidget {
  const _AddSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AddSheetTile(
              icon: Icons.document_scanner_outlined,
              title: 'Scan document',
              subtitle: 'Camera · auto edge detection · multi-page PDF',
              onTap: () => Navigator.pop(context, _AddAction.scan),
            ),
            Divider(height: 1, color: c.border),
            _AddSheetTile(
              icon: Icons.photo_library_outlined,
              title: 'Add from gallery',
              subtitle: 'Pick photos from your device gallery',
              onTap: () => Navigator.pop(context, _AddAction.fromGallery),
            ),
            Divider(height: 1, color: c.border),
            _AddSheetTile(
              icon: Icons.upload_file_outlined,
              title: 'Import file',
              subtitle: 'Pick existing files from device storage',
              onTap: () => Navigator.pop(context, _AddAction.importFile),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSheetTile extends StatelessWidget {
  const _AddSheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: c.fg),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: c.fg, fontSize: 14.5)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppMono.of(context, size: 10, color: c.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: c.muted2),
          ],
        ),
      ),
    );
  }
}

class _AppSnack {
  _AppSnack({required this.message, this.error = false});
  final String message;
  final bool error;

  SnackBar build(BuildContext context) {
    final c = context.c;
    return SnackBar(
      content: Row(
        children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            size: 14,
            color: error ? c.error : c.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: error ? c.error : c.fg,
                fontSize: 12.5,
                fontWeight: error ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: error ? c.errorSoft : c.surface2,
      duration: const Duration(seconds: 3),
    );
  }
}
