import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import 'vault_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.vault});

  final VaultService vault;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pwd = TextEditingController();
  bool _busy = false;
  bool _showPwd = false;
  String? _error;
  bool _biometricAvailable = false;
  bool _initialAttempted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialAttempted) {
      _initialAttempted = true;
      _maybeAutoBiometric();
    }
  }

  Future<void> _maybeAutoBiometric() async {
    final services = AppScope.of(context);
    final enabled = services.lockSettings.biometricEnabled;
    final available = await services.biometrics.isAvailable;
    if (!mounted) return;
    setState(() => _biometricAvailable = available && enabled);
    if (available && enabled) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      _doBiometric();
    }
  }

  Future<void> _doBiometric() async {
    final services = AppScope.of(context);
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await services.biometrics.authenticate(
        reason: 'Unlock SecDockKeeper',
      );
      if (!ok) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final pwd = await services.lockSettings.readStoredPassword();
      if (pwd == null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = 'Stored credentials missing. Enter password.';
          });
        }
        return;
      }
      final success = await widget.vault.unlock(pwd);
      if (!success && mounted) {
        await services.lockSettings.disableBiometric();
        setState(() {
          _busy = false;
          _biometricAvailable = false;
          _error = 'Stored password no longer valid. Enter manually.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Biometric failed: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _pwd.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await widget.vault.unlock(_pwd.text);
      if (!ok && mounted) {
        setState(() {
          _error = 'Incorrect password';
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to unlock: $e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [scheme.primary, scheme.tertiary],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(Icons.lock_outline, color: scheme.onPrimary, size: 36),
                  ),
                  const SizedBox(height: 28),
                  Text('Welcome back', style: t.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your master password to unlock the vault.',
                    style: t.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _pwd,
                    obscureText: !_showPwd,
                    autofocus: !_biometricAvailable,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Master password',
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_showPwd ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _showPwd = !_showPwd),
                      ),
                    ),
                  ),
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
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : const Text('Unlock'),
                  ),
                  if (_biometricAvailable) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _doBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Use biometric'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
