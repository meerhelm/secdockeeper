import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../folders/folder.dart';
import '../tags/tag.dart';
import 'document.dart';
import 'document_detail_screen.dart';

typedef _Services = AppServices;

class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  final _searchCtl = TextEditingController();
  String _query = '';
  bool _importing = false;
  final Set<int> _activeTagIds = {};
  _FolderScope _folderScope = const _FolderScope.all();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<void>(
          stream: services.documents.changes,
          builder: (context, _) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [scheme.primary, scheme.tertiary],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.shield_outlined,
                              color: scheme.onPrimary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Vault', style: t.titleLarge),
                              Text(
                                'Encrypted documents',
                                style: t.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        _IconChipButton(
                          icon: Icons.lock_outline,
                          onTap: () async {
                            await services.opener.deleteAllTemp();
                            await services.vault.lock();
                          },
                          tooltip: 'Lock',
                        ),
                        const SizedBox(width: 8),
                        _OverflowMenu(
                          onImportShare: _importShared,
                          onExportBackup: _exportBackup,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: TextField(
                      controller: _searchCtl,
                      decoration: InputDecoration(
                        hintText: 'Search by name, content or hidden tag…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchCtl.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _FoldersRow(
                    scope: _folderScope,
                    onSelect: (s) => setState(() => _folderScope = s),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _FilterRow(
                    activeCount: _activeTagIds.length,
                    onTap: _openTagFilter,
                    onClear: _activeTagIds.isEmpty
                        ? null
                        : () => setState(_activeTagIds.clear),
                  ),
                ),
                FutureBuilder<List<Document>>(
                  future: _runSearch(services),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final docs = snapshot.data!;
                    if (docs.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                      sliver: SliverList.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _DocumentCard(document: docs[i]),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _import,
        icon: _importing
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add),
        label: const Text('Import'),
      ),
    );
  }

  Future<void> _import() async {
    final services = AppScope.of(context);
    final result = await FilePicker.pickFiles(
      withData: true,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() => _importing = true);
    try {
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes != null) {
          await services.importer.importBytes(
            bytes: bytes,
            originalName: f.name,
          );
        } else if (f.path != null) {
          await services.importer.importFile(File(f.path!));
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${result.files.length} file(s)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _exportBackup() async {
    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importing = true);
    try {
      await services.opener.deleteAllTemp();
      final backup = await services.backup.exportVault();
      await services.backup.shareViaSystem(backup);
      messenger.showSnackBar(
        SnackBar(content: Text('Backup ready: ${backup.file.path.split('/').last}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importShared() async {
    final services = AppScope.of(context);
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

    setState(() => _importing = true);
    try {
      await services.share.importPackage(
        blobFile: File(blobPath),
        keyFile: File(keyPath),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared document imported')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<List<Document>> _runSearch(_Services services) async {
    final tagIds = _activeTagIds.isEmpty ? null : _activeTagIds.toList();
    final hasQuery = _query.isNotEmpty;
    final folderId = _folderScope.specificId;
    final onlyUnassigned = _folderScope.isUnassigned;
    final normal = await services.documents.list(
      query: hasQuery ? _query : null,
      tagIds: tagIds,
      folderId: folderId,
      onlyUnassignedFolder: onlyUnassigned,
    );
    if (!hasQuery) return normal;

    final results = await Future.wait([
      services.tags.findDocumentsByQuery(_query),
      services.hiddenTags.findDocumentsByName(_query),
    ]);
    final byTagDocIds = <int>{...results[0], ...results[1]};
    if (byTagDocIds.isEmpty) return normal;

    final byTags = await services.documents.list(
      tagIds: tagIds,
      hiddenDocIds: byTagDocIds.toList(),
      folderId: folderId,
      onlyUnassignedFolder: onlyUnassigned,
    );

    final seen = <int>{};
    final merged = <Document>[];
    for (final d in byTags) {
      if (seen.add(d.id)) merged.add(d);
    }
    for (final d in normal) {
      if (seen.add(d.id)) merged.add(d);
    }
    return merged;
  }

  Future<void> _openTagFilter() async {
    final services = AppScope.of(context);
    final all = await services.tags.listAll();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('Filter by tags',
                            style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheet(() => _activeTagIds.clear());
                            setState(() {});
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (all.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No tags yet. Create them on document detail screen.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final Tag t in all)
                              CheckboxListTile(
                                value: _activeTagIds.contains(t.id),
                                title: Text(t.name),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                onChanged: (v) {
                                  setSheet(() {
                                    if (v == true) {
                                      _activeTagIds.add(t.id);
                                    } else {
                                      _activeTagIds.remove(t.id);
                                    }
                                  });
                                  setState(() {});
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FolderScope {
  const _FolderScope.all() : id = null, kind = _FolderScopeKind.all;
  const _FolderScope.unassigned() : id = null, kind = _FolderScopeKind.unassigned;
  const _FolderScope.specific(int folderId)
      : id = folderId,
        kind = _FolderScopeKind.specific;

  final int? id;
  final _FolderScopeKind kind;

  bool get isAll => kind == _FolderScopeKind.all;
  bool get isUnassigned => kind == _FolderScopeKind.unassigned;
  int? get specificId => kind == _FolderScopeKind.specific ? id : null;
}

enum _FolderScopeKind { all, unassigned, specific }

class _FoldersRow extends StatelessWidget {
  const _FoldersRow({required this.scope, required this.onSelect});

  final _FolderScope scope;
  final ValueChanged<_FolderScope> onSelect;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return SizedBox(
      height: 44,
      child: StreamBuilder<void>(
        stream: services.folders.changes,
        builder: (context, _) {
          return FutureBuilder<List<Folder>>(
            future: services.folders.listAll(),
            builder: (context, snap) {
              final folders = snap.data ?? const <Folder>[];
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                children: [
                  _FolderChip(
                    icon: Icons.all_inbox_outlined,
                    label: 'All',
                    selected: scope.isAll,
                    onTap: () => onSelect(const _FolderScope.all()),
                  ),
                  const SizedBox(width: 8),
                  _FolderChip(
                    icon: Icons.inbox_outlined,
                    label: 'No folder',
                    selected: scope.isUnassigned,
                    onTap: () => onSelect(const _FolderScope.unassigned()),
                  ),
                  for (final f in folders) ...[
                    const SizedBox(width: 8),
                    _FolderChip(
                      icon: Icons.folder_outlined,
                      label: f.name,
                      count: f.documentCount,
                      selected: scope.specificId == f.id,
                      onTap: () => onSelect(_FolderScope.specific(f.id)),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _AddFolderChip(onTap: () => _showCreateFolder(context)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateFolder(BuildContext context) async {
    final ctl = TextEditingController();
    final services = AppScope.of(context);
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      final folder = await services.folders.create(name.trim());
      onSelect(_FolderScope.specific(folder.id));
    }
  }
}

class _FolderChip extends StatelessWidget {
  const _FolderChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    final bg = selected ? scheme.primary : scheme.surfaceContainerHigh;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.onPrimary.withValues(alpha: 0.18)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: fg,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFolderChip extends StatelessWidget {
  const _AddFolderChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: scheme.outlineVariant,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.add, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'New',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChipButton extends StatelessWidget {
  const _IconChipButton({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final btn = Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 40, height: 40,
          child: Icon(icon, size: 20, color: scheme.onSurface),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.onImportShare, required this.onExportBackup});
  final VoidCallback onImportShare;
  final VoidCallback onExportBackup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'import_share') onImportShare();
          if (v == 'export_backup') onExportBackup();
        },
        offset: const Offset(0, 48),
        icon: Icon(Icons.more_horiz, size: 20, color: scheme.onSurface),
        tooltip: 'More',
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'import_share',
            child: ListTile(
              leading: Icon(Icons.move_to_inbox_outlined),
              title: Text('Import shared package'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'export_backup',
            child: ListTile(
              leading: Icon(Icons.archive_outlined),
              title: Text('Export full backup'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.activeCount, required this.onTap, this.onClear});
  final int activeCount;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final has = activeCount > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          ActionChip(
            avatar: Icon(
              has ? Icons.filter_list : Icons.filter_list_outlined,
              size: 18,
              color: has ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
            label: Text(has ? '$activeCount tag${activeCount > 1 ? "s" : ""}' : 'Filter'),
            backgroundColor:
                has ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            labelStyle: TextStyle(
              color: has ? scheme.onPrimaryContainer : scheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            onPressed: onTap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide.none,
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final accent = _accentForMime(document.mimeType, scheme);

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentDetailScreen(documentId: document.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: accent.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(document.mimeType), color: accent.fg, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${_formatSize(document.size)} • ${_formatDate(document.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    if (document.classification != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          document.classification!,
                          style: t.bodySmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String? mime) {
    if (mime == null) return Icons.insert_drive_file_outlined;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('text/')) return Icons.text_snippet_outlined;
    if (mime.startsWith('video/')) return Icons.movie_outlined;
    if (mime.startsWith('audio/')) return Icons.music_note_outlined;
    return Icons.insert_drive_file_outlined;
  }

  _Accent _accentForMime(String? mime, ColorScheme s) {
    if (mime == null) return _Accent(s.surfaceContainerHighest, s.onSurfaceVariant);
    if (mime.startsWith('image/')) {
      return _Accent(s.tertiaryContainer, s.onTertiaryContainer);
    }
    if (mime == 'application/pdf') {
      return _Accent(s.errorContainer, s.onErrorContainer);
    }
    if (mime.startsWith('text/')) {
      return _Accent(s.secondaryContainer, s.onSecondaryContainer);
    }
    return _Accent(s.primaryContainer, s.onPrimaryContainer);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'today ${_pad(d.hour)}:${_pad(d.minute)}';
    }
    if (d.year == now.year) {
      return '${_pad(d.day)}.${_pad(d.month)}';
    }
    return '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

class _Accent {
  _Accent(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.folder_open_outlined,
                size: 44, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 20),
          Text('Vault is empty', style: t.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Tap Import to add your first encrypted document.',
            style: t.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
