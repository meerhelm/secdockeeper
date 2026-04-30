import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../folders/folder.dart';
import '../folders/folder_picker_sheet.dart';
import '../hidden_tags/hidden_tags_sheet.dart';
import '../tags/tag.dart';
import '../tags/tag_picker_sheet.dart';
import 'document.dart';

class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({super.key, required this.documentId});

  final int documentId;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  Document? _document;
  bool _busy = false;
  String? _error;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final services = AppScope.of(context);
    final doc = await services.documents.getById(widget.documentId);
    if (!mounted) return;
    setState(() => _document = doc);
  }

  Future<void> _open() async {
    final services = AppScope.of(context);
    final doc = _document;
    if (doc == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await services.opener.open(doc);
    } catch (e) {
      setState(() => _error = 'Failed to open: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename() async {
    final services = AppScope.of(context);
    final doc = _document;
    if (doc == null) return;
    final controller = TextEditingController(text: doc.originalName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename document'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'New name',
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (newName == null) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == doc.originalName) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await services.documents.rename(doc.id, trimmed);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = 'Rename failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final services = AppScope.of(context);
    final doc = _document;
    if (doc == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final export = await services.share.exportDocument(doc);
      await services.share.shareViaSystem(export);
    } catch (e) {
      if (mounted) setState(() => _error = 'Share failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final services = AppScope.of(context);
    final doc = _document;
    if (doc == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('${doc.originalName} will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await services.vault.blobStore.delete(doc.uuid);
      await services.documents.deleteById(doc.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Delete failed: $e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _document;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (doc != null) ...[
            IconButton(
              icon: const Icon(Icons.drive_file_rename_outline),
              tooltip: 'Rename',
              onPressed: _busy ? null : _rename,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _busy ? null : _delete,
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: doc == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _Hero(document: doc),
                  const SizedBox(height: 24),
                  _MetaCard(document: doc),
                  const SizedBox(height: 16),
                  _SectionHeader(title: 'Folder'),
                  const SizedBox(height: 8),
                  _FolderBlock(document: doc, onChanged: _load),
                  const SizedBox(height: 20),
                  _SectionHeader(title: 'Tags'),
                  const SizedBox(height: 8),
                  _TagsBlock(documentId: doc.id),
                  const SizedBox(height: 20),
                  _SectionHeader(title: 'Actions'),
                  const SizedBox(height: 8),
                  _ActionGroup(
                    children: [
                      _ActionTile(
                        icon: Icons.open_in_new,
                        title: 'Open decrypted',
                        subtitle: 'Decrypt to a temporary file and open in system viewer',
                        onTap: _busy ? null : _open,
                        color: scheme.primary,
                      ),
                      _ActionTile(
                        icon: Icons.ios_share,
                        title: 'Share encrypted',
                        subtitle: 'Export blob + key file via system share sheet',
                        onTap: _busy ? null : _share,
                        color: scheme.tertiary,
                      ),
                      _ActionTile(
                        icon: Icons.visibility_off_outlined,
                        title: 'Hidden tags',
                        subtitle: 'Manage deniable tags revealed only by name match',
                        onTap: () => HiddenTagsSheet.show(context, doc.id),
                        color: scheme.secondary,
                      ),
                    ],
                  ),
                  if (doc.ocrText != null && doc.ocrText!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'Recognized text'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(doc.ocrText!, style: t.bodyMedium),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: t.bodyMedium?.copyWith(color: scheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.document});
  final Document document;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final accent = _heroAccent(document.mimeType, scheme);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.start, accent.end],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_iconFor(document.mimeType), color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.originalName,
                  style: t.titleLarge?.copyWith(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.lock_outline,
                        size: 14, color: Colors.white.withValues(alpha: 0.85)),
                    const SizedBox(width: 4),
                    Text(
                      'AES-256-GCM • encrypted at rest',
                      style: t.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String? mime) {
    if (mime == null) return Icons.insert_drive_file_outlined;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('text/')) return Icons.text_snippet_outlined;
    return Icons.insert_drive_file_outlined;
  }

  _HeroAccent _heroAccent(String? mime, ColorScheme s) {
    if (mime != null && mime == 'application/pdf') {
      return _HeroAccent(const Color(0xFFE03131), const Color(0xFFFA5252));
    }
    if (mime != null && mime.startsWith('image/')) {
      return _HeroAccent(const Color(0xFF7950F2), const Color(0xFFD6336C));
    }
    return _HeroAccent(s.primary, s.tertiary);
  }
}

class _HeroAccent {
  _HeroAccent(this.start, this.end);
  final Color start;
  final Color end;
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.document});
  final Document document;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _MetaRow(label: 'MIME', value: document.mimeType ?? 'unknown'),
          _MetaDivider(),
          _MetaRow(label: 'Size', value: _formatSize(document.size)),
          _MetaDivider(),
          _MetaRow(label: 'Created', value: _formatDate(document.createdAt)),
          if (document.classification != null) ...[
            _MetaDivider(),
            _MetaRow(label: 'Class', value: document.classification!),
          ],
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime d) {
    final l = d.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${pad(l.month)}-${pad(l.day)} ${pad(l.hour)}:${pad(l.minute)}';
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label.toUpperCase(),
                style: t.bodySmall?.copyWith(
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: t.bodyMedium)),
        ],
      ),
    );
  }
}

class _MetaDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: t.bodySmall?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FolderBlock extends StatelessWidget {
  const _FolderBlock({required this.document, required this.onChanged});
  final Document document;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return StreamBuilder<void>(
      stream: services.folders.changes,
      builder: (context, _) {
        final futureFolder = document.folderId == null
            ? Future<Folder?>.value(null)
            : services.folders.getById(document.folderId!);
        return FutureBuilder<Folder?>(
          future: futureFolder,
          builder: (context, snap) {
            final folder = snap.data;
            return Material(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await FolderPickerSheet.show(
                    context, document.id, document.folderId);
                  await onChanged();
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: (folder == null
                                  ? scheme.surfaceContainerHighest
                                  : scheme.primaryContainer),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          folder == null ? Icons.inbox_outlined : Icons.folder_outlined,
                          color: folder == null
                              ? scheme.onSurfaceVariant
                              : scheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          folder?.name ?? 'No folder',
                          style: t.titleSmall,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TagsBlock extends StatelessWidget {
  const _TagsBlock({required this.documentId});
  final int documentId;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<void>(
      stream: services.tags.changes,
      builder: (context, _) {
        return FutureBuilder<List<Tag>>(
          future: services.tags.forDocument(documentId),
          builder: (context, snap) {
            final tags = snap.data ?? const <Tag>[];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tags.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        'No tags assigned',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: [
                        for (final t in tags)
                          Chip(
                            label: Text(t.name),
                            onDeleted: () => services.tags.unassign(documentId, t.id),
                            deleteIconColor: scheme.onSurfaceVariant,
                            backgroundColor: scheme.primaryContainer,
                            labelStyle: TextStyle(color: scheme.onPrimaryContainer),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => TagPickerSheet.show(context, documentId),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Manage tags'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 64,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: t.bodySmall, maxLines: 2),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
