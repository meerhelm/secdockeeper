import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import 'tag.dart';

class TagPickerSheet extends StatefulWidget {
  const TagPickerSheet({super.key, required this.documentId});

  final int documentId;

  static Future<void> show(BuildContext context, int documentId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TagPickerSheet(documentId: documentId),
    );
  }

  @override
  State<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<TagPickerSheet> {
  final _search = TextEditingController();
  Future<_PickerData>? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  Future<_PickerData> _load() async {
    final services = AppScope.of(context);
    final all = await services.tags.listAll();
    final assigned = await services.tags.forDocument(widget.documentId);
    return _PickerData(all: all, assigned: assigned.map((t) => t.id).toSet());
  }

  void _refresh() => setState(() => _data = _load());

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
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
            Text('Tags', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search or create tag',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
              onSubmitted: (v) async {
                final name = v.trim();
                if (name.isEmpty) return;
                final tag = await services.tags.upsert(name);
                await services.tags.assign(widget.documentId, tag.id);
                _search.clear();
                _refresh();
              },
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: FutureBuilder<_PickerData>(
                future: _data,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snap.data!;
                  final query = _search.text.trim().toLowerCase();
                  final filtered = query.isEmpty
                      ? data.all
                      : data.all.where((t) => t.name.toLowerCase().contains(query)).toList();
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      if (query.isNotEmpty &&
                          !data.all.any((t) => t.name.toLowerCase() == query))
                        ListTile(
                          leading: const Icon(Icons.add),
                          title: Text('Create "${_search.text.trim()}"'),
                          onTap: () async {
                            final tag =
                                await services.tags.upsert(_search.text.trim());
                            await services.tags.assign(widget.documentId, tag.id);
                            _search.clear();
                            _refresh();
                          },
                        ),
                      ...filtered.map((t) {
                        final assigned = data.assigned.contains(t.id);
                        return CheckboxListTile(
                          value: assigned,
                          title: Text(t.name),
                          onChanged: (v) async {
                            if (v == true) {
                              await services.tags.assign(widget.documentId, t.id);
                            } else {
                              await services.tags.unassign(widget.documentId, t.id);
                            }
                            _refresh();
                          },
                        );
                      }),
                    ],
                  );
                },
              ),
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

class _PickerData {
  _PickerData({required this.all, required this.assigned});
  final List<Tag> all;
  final Set<int> assigned;
}
