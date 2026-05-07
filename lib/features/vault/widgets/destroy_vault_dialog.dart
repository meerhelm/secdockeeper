import 'package:flutter/material.dart';

import '../../../app/tokens.dart';

class DestroyVaultDialog extends StatefulWidget {
  const DestroyVaultDialog({super.key});

  @override
  State<DestroyVaultDialog> createState() => _DestroyVaultDialogState();
}

class _DestroyVaultDialogState extends State<DestroyVaultDialog> {
  static const _phrase = 'DESTROY';
  final _ctl = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _ctl.addListener(_recheck);
  }

  void _recheck() {
    final next = _ctl.text == _phrase;
    if (next != _matches) setState(() => _matches = next);
  }

  @override
  void dispose() {
    _ctl.removeListener(_recheck);
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AlertDialog(
      title: Text('Destroy vault?', style: TextStyle(color: c.error)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This permanently deletes every document, tag, and key. '
            'There is no undo and no recovery — only a previously exported '
            'backup can restore your data.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctl,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Type DESTROY to confirm',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: c.fg),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: c.error,
            foregroundColor: c.fgStrong,
          ),
          child: const Text('Destroy vault'),
        ),
      ],
    );
  }
}
