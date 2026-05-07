import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../app/widgets/badges.dart';
import '../../app/widgets/icon_chip_button.dart';
import '../../app/widgets/meta_card.dart';
import '../../app/widgets/row_tile.dart';
import '../../app/widgets/section_label.dart';
import '../folders/folder_picker_sheet.dart';
import '../hidden_tags/hidden_tags_sheet.dart';
import '../tags/tag_picker_sheet.dart';
import 'cubit/document_detail_cubit.dart';
import 'cubit/document_detail_state.dart';
import 'document.dart';

class DocumentDetailScreen extends StatelessWidget {
  const DocumentDetailScreen({super.key});

  Future<void> _rename(BuildContext context, Document doc) async {
    final c = context.c;
    final controller = TextEditingController(text: doc.originalName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
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
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || !context.mounted) return;
    await context.read<DocumentDetailCubit>().rename(newName);
  }

  Future<void> _confirmDelete(BuildContext context, Document doc) async {
    final c = context.c;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.errorSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.delete_outline, size: 26, color: c.error),
            ),
            const SizedBox(height: 14),
            const Text('Delete document'),
          ],
        ),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 4),
        content: RichText(
          text: TextSpan(
            style: TextStyle(
              color: c.muted,
              fontSize: 13.5,
              height: 1.55,
            ),
            children: [
              TextSpan(
                text: doc.originalName,
                style: TextStyle(color: c.fg, fontWeight: FontWeight.w500),
              ),
              const TextSpan(
                text: ' will be permanently removed from this vault. The file '
                    'is overwritten in storage; it cannot be recovered.',
              ),
            ],
          ),
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
    if (confirmed != true || !context.mounted) return;
    await context.read<DocumentDetailCubit>().delete();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final messenger = ScaffoldMessenger.of(context);

    return BlocConsumer<DocumentDetailCubit, DocumentDetailState>(
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
        final doc = state.document;
        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: Column(
              children: [
                _AppBar(
                  showActions: doc != null,
                  busy: state.busy,
                  onBack: () => context.pop(),
                  onRename: doc == null ? null : () => _rename(context, doc),
                  onDelete:
                      doc == null ? null : () => _confirmDelete(context, doc),
                ),
                Expanded(
                  child: doc == null
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _Hero(document: doc),
                            ),
                            const SectionLabel('Properties'),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _PropertiesCard(document: doc),
                            ),
                            const SectionLabel('Folder'),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: RowTileCard(
                                icon: state.folder == null
                                    ? Icons.inbox_outlined
                                    : Icons.folder_outlined,
                                title: state.folder?.name ?? 'No folder',
                                subtitle: state.folder == null
                                    ? null
                                    : '${state.folder!.documentCount} document${state.folder!.documentCount == 1 ? "" : "s"}',
                                onTap: () => FolderPickerSheet.show(
                                  context, doc.id, doc.folderId,
                                ),
                              ),
                            ),
                            const SectionLabel('Tags'),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _TagsCard(state: state),
                            ),
                            const SectionLabel('Actions'),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: RowTileGroup(
                                children: [
                                  RowTile(
                                    icon: Icons.open_in_new,
                                    title: 'Open decrypted',
                                    subtitle:
                                        'Decrypt to a temporary file and open in the system viewer.',
                                    primary: true,
                                    onTap: state.busy
                                        ? null
                                        : () => context
                                            .read<DocumentDetailCubit>()
                                            .open(),
                                  ),
                                  RowTile(
                                    icon: Icons.share_outlined,
                                    title: 'Share encrypted',
                                    subtitle:
                                        'Export blob + key file via the system share sheet.',
                                    onTap: state.busy
                                        ? null
                                        : () => context
                                            .read<DocumentDetailCubit>()
                                            .share(),
                                  ),
                                  RowTile(
                                    icon: Icons.visibility_off_outlined,
                                    title: 'Hidden tags',
                                    subtitle:
                                        'Manage deniable tags — revealed only by exact-name search.',
                                    onTap: () => HiddenTagsSheet.show(
                                      context, doc.id,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (doc.ocrText != null && doc.ocrText!.isNotEmpty) ...[
                              const SectionLabel('Recognized text · OCR'),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _OcrBlock(text: doc.ocrText!),
                              ),
                            ],
                          ],
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

class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.showActions,
    required this.busy,
    required this.onBack,
    required this.onRename,
    required this.onDelete,
  });

  final bool showActions;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconChipButton(
            icon: Icons.arrow_back_ios_new,
            onTap: onBack,
            ghost: true,
          ),
          const Spacer(),
          if (showActions) ...[
            IconChipButton(
              icon: Icons.drive_file_rename_outline,
              onTap: busy ? null : onRename,
              ghost: true,
              tooltip: 'Rename',
            ),
            const SizedBox(width: 4),
            IconChipButton(
              icon: Icons.delete_outline,
              onTap: busy ? null : onDelete,
              ghost: true,
              tooltip: 'Delete',
            ),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.document});
  final Document document;

  @override
  Widget build(BuildContext context) {
    final mime = document.mimeType;
    final palette = _palette(mime);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.7, -0.9),
          end: const Alignment(0.9, 0.9),
          colors: palette,
          stops: const [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_icon(mime), color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  document.originalName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.31,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline,
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.85)),
                    const SizedBox(width: 5),
                    Text(
                      'AES-256-GCM · ENCRYPTED AT REST',
                      style: AppMono.of(
                        context,
                        size: 10,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 1.4,
                        weight: FontWeight.w500,
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

  static IconData _icon(String? mime) {
    if (mime == null) return Icons.insert_drive_file_outlined;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('text/')) return Icons.text_snippet_outlined;
    return Icons.insert_drive_file_outlined;
  }

  static List<Color> _palette(String? mime) {
    if (mime == 'application/pdf') {
      return const [Color(0xFF3A1010), Color(0xFF6E2323), Color(0xFFC54343)];
    }
    if (mime != null && mime.startsWith('image/')) {
      return const [Color(0xFF2C1230), Color(0xFF5B1F3D), Color(0xFFB34A4D)];
    }
    if (mime != null && mime.startsWith('text/')) {
      return const [Color(0xFF1F2D2D), Color(0xFF2A4A4A), Color(0xFF6FA0A0)];
    }
    return const [Color(0xFF1F2A40), Color(0xFF2C3A5A), Color(0xFF6B83B5)];
  }
}

class _PropertiesCard extends StatelessWidget {
  const _PropertiesCard({required this.document});
  final Document document;

  String _formatBytes(int bytes) {
    String pretty;
    if (bytes < 1024) {
      pretty = '$bytes B';
    } else if (bytes < 1024 * 1024) {
      pretty = '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      pretty = '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      pretty = '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
    }
    final formatted = bytes
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$formatted bytes · $pretty';
  }

  String _formatDate(DateTime d) {
    final l = d.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    final tz = l.timeZoneOffset;
    final tzSign = tz.isNegative ? '-' : '+';
    final tzHours = tz.inHours.abs();
    return '${l.year}-${pad(l.month)}-${pad(l.day)} · '
        '${pad(l.hour)}:${pad(l.minute)} GMT$tzSign$tzHours';
  }

  @override
  Widget build(BuildContext context) {
    return MetaCard(
      rows: [
        MetaRow(label: 'MIME', value: document.mimeType ?? 'unknown'),
        MetaRow(label: 'Size', value: _formatBytes(document.size)),
        MetaRow(label: 'Created', value: _formatDate(document.createdAt)),
        if (document.classification != null)
          MetaRow(
            label: 'Class',
            value: '',
            trailing: MetaPill('${document.classification} · auto'),
          ),
      ],
    );
  }
}

class _TagsCard extends StatelessWidget {
  const _TagsCard({required this.state});
  final DocumentDetailState state;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.tags.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No tags assigned',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in state.tags)
                  TagChip(
                    label: t.name,
                    onDeleted: () => context
                        .read<DocumentDetailCubit>()
                        .unassignTag(t.id),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => TagPickerSheet.show(context, state.document!.id),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 14, color: c.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Manage tags',
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OcrBlock extends StatelessWidget {
  const _OcrBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1),
      ),
      constraints: const BoxConstraints(maxHeight: 220),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Text(
              text,
              style: AppMono.of(
                context,
                size: 11.5,
                color: c.fg,
              ).copyWith(height: 1.55),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.surface.withValues(alpha: 0), c.surface],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
