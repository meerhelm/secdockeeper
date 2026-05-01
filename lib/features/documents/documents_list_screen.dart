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
import '../tags/tag.dart';
import 'cubit/documents_list_cubit.dart';
import 'cubit/documents_list_state.dart';
import 'document.dart';
import 'folder_scope.dart';
import 'usecases/import_files.dart';
import 'widgets/document_thumb.dart';

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

  Future<void> _import() async {
    final cubit = context.read<DocumentsListCubit>();
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

        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _VaultHeader(
                      onLock: () => context.read<DocumentsListCubit>().lock(),
                      onImportShared: _importShared,
                      onExportBackup: () =>
                          context.read<DocumentsListCubit>().exportBackup(),
                    )),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: AppSearchField(
                          controller: _searchCtl,
                          hintText:
                              'Search by name, content or hidden tag…',
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
                        onFilter: _openTagFilter,
                        onSelect: (s) =>
                            context.read<DocumentsListCubit>().setFolderScope(s),
                        onAddFolder: _showCreateFolder,
                      ),
                    ),
                    SliverToBoxAdapter(child: _StatsRow(
                      count: state.documents.length,
                      sizeText: _formatTotalSize(state.documents),
                    )),
                    if (state.loadingDocuments)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.documents.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
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
                    onPressed: state.busy ? null : _import,
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
                    label: const Text('Import'),
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
    required this.onLock,
    required this.onImportShared,
    required this.onExportBackup,
  });

  final VoidCallback onLock;
  final VoidCallback onImportShared;
  final VoidCallback onExportBackup;

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
              'Vault',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconChipButton(
            icon: Icons.lock_outline,
            onTap: onLock,
            tooltip: 'Lock',
          ),
          const SizedBox(width: 8),
          _OverflowMenu(
            onImportShared: onImportShared,
            onExportBackup: onExportBackup,
          ),
        ],
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.onImportShared, required this.onExportBackup});
  final VoidCallback onImportShared;
  final VoidCallback onExportBackup;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'import_share') onImportShared();
        if (v == 'export_backup') onExportBackup();
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
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.title, required this.sub});
  final IconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Icon(icon, size: 16, color: c.muted),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: TextStyle(fontSize: 14, color: c.fg)),
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
    required this.onFilter,
    required this.onSelect,
    required this.onAddFolder,
  });

  final FolderScope scope;
  final List<Folder> folders;
  final bool hasFilter;
  final int filterCount;
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
          AppChip(
            label: 'Filter',
            count: hasFilter ? filterCount : null,
            selected: hasFilter,
            icon: Icons.tune,
            onTap: onFilter,
          ),
          const SizedBox(width: 8),
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
  const _StatsRow({required this.count, required this.sizeText});
  final int count;
  final String sizeText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Text(
            '${count.toString().padLeft(2, '0')} documents · $sizeText'.toUpperCase(),
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
              style: TextStyle(color: c.fg, fontSize: 12.5),
            ),
          ),
        ],
      ),
      backgroundColor: c.surface2,
      duration: const Duration(seconds: 3),
    );
  }
}
