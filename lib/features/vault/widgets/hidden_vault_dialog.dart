import 'package:flutter/material.dart';

import '../../../app/tokens.dart';

/// Password dialog used both to suggest a hidden vault during onboarding and to
/// (re)create it from settings. Returns the chosen password, or null if the
/// user skipped/cancelled. Enforces the same 12-char minimum as the primary
/// password and that the two fields match.
Future<String?> showHiddenVaultDialog(
  BuildContext context, {
  String confirmLabel = 'Create',
  String cancelLabel = 'Skip',
  bool replacing = false,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _HiddenVaultDialog(
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      replacing: replacing,
    ),
  );
}

class _HiddenVaultDialog extends StatefulWidget {
  const _HiddenVaultDialog({
    required this.confirmLabel,
    required this.cancelLabel,
    required this.replacing,
  });

  final String confirmLabel;
  final String cancelLabel;
  final bool replacing;

  @override
  State<_HiddenVaultDialog> createState() => _HiddenVaultDialogState();
}

class _HiddenVaultDialogState extends State<_HiddenVaultDialog> {
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_pwd.text.length < 12) {
      setState(() => _error = 'Use at least 12 characters.');
      return;
    }
    if (_pwd.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    Navigator.pop(context, _pwd.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AlertDialog(
      title: const Text('Hidden vault'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A hidden vault is opened by typing its own password on the normal '
            'unlock screen — nothing reveals it exists. It is wiped '
            'automatically after 3 wrong password attempts. Choose a password '
            'different from your main one.',
            style: TextStyle(color: c.muted, fontSize: 13, height: 1.5),
          ),
          if (widget.replacing) ...[
            const SizedBox(height: 10),
            Text(
              'This replaces any existing hidden vault — its contents are lost.',
              style: TextStyle(color: c.error, fontSize: 12.5, height: 1.45),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _pwd,
            autofocus: true,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Hidden vault password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: c.error, fontSize: 12.5)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          style: TextButton.styleFrom(foregroundColor: c.fg),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
