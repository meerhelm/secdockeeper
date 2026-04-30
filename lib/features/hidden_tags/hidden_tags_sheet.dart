import 'package:flutter/material.dart';

import '../../app/app_scope.dart';

class HiddenTagsSheet extends StatefulWidget {
  const HiddenTagsSheet({super.key, required this.documentId});

  final int documentId;

  static Future<void> show(BuildContext context, int documentId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => HiddenTagsSheet(documentId: documentId),
    );
  }

  @override
  State<HiddenTagsSheet> createState() => _HiddenTagsSheetState();
}

class _HiddenTagsSheetState extends State<HiddenTagsSheet> {
  final _input = TextEditingController();
  Future<List<String>>? _names;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _names ??= _load();
  }

  Future<List<String>> _load() {
    return AppScope.of(context).hiddenTags.namesForDocument(widget.documentId);
  }

  void _refresh() => setState(() => _names = _load());

  Future<void> _add() async {
    final name = _input.text.trim();
    if (name.isEmpty) return;
    await AppScope.of(context).hiddenTags.assignByName(widget.documentId, name);
    _input.clear();
    _refresh();
  }

  Future<void> _remove(String name) async {
    await AppScope.of(context).hiddenTags.removeByName(widget.documentId, name);
    _refresh();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.visibility_off_outlined),
                const SizedBox(width: 8),
                Text('Hidden tags', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tags here are stored as cryptographic hashes. They never appear in the UI '
              'unless someone types the exact tag name into the search bar.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(
                      labelText: 'Hidden tag name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(),
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<String>>(
              future: _names,
              builder: (context, snap) {
                final names = snap.data;
                if (names == null) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (names.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hidden tags assigned yet.'),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final n in names)
                        ListTile(
                          leading: const Icon(Icons.tag),
                          title: Text(n),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _remove(n),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
