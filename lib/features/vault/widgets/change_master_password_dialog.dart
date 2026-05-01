import 'package:flutter/material.dart';
import '../../../app/tokens.dart';

class ChangeMasterPasswordDialog extends StatefulWidget {
  const ChangeMasterPasswordDialog({super.key});

  @override
  State<ChangeMasterPasswordDialog> createState() => _ChangeMasterPasswordDialogState();
}

class _ChangeMasterPasswordDialogState extends State<ChangeMasterPasswordDialog> {
  final _newPasswordCtl = TextEditingController();
  final _confirmPasswordCtl = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _newPasswordCtl.dispose();
    _confirmPasswordCtl.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _newPasswordCtl.text;
    final confirm = _confirmPasswordCtl.text;

    if (password.isEmpty) {
      setState(() => _error = 'Password cannot be empty');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    Navigator.pop(context, password);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AlertDialog(
      title: const Text('Change master password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This will re-encrypt all document keys. Do not forget your new password, as there is no way to recover it.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newPasswordCtl,
            autofocus: true,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'New master password',
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordCtl,
            obscureText: _obscure,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: c.fg),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Change'),
        ),
      ],
    );
  }
}
