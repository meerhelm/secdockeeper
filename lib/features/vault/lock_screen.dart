import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/tokens.dart';
import '../../app/widgets/app_buttons.dart';
import '../../app/widgets/app_field.dart';
import '../../app/widgets/brand_mark.dart';
import '../security/biometric_service.dart';
import 'cubit/lock_cubit.dart';
import 'cubit/lock_state.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pwd = TextEditingController();
  bool _showPwd = false;
  bool _passwordExpanded = false;
  Timer? _tickTimer;
  DateTime? _trackedLockedUntil;

  @override
  void initState() {
    super.initState();
    context.read<LockCubit>().init();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _pwd.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<LockCubit>().submit(_pwd.text);
  }

  void _doBiometric() {
    context.read<LockCubit>().tryBiometric();
  }

  void _syncCountdownTimer(DateTime? lockedUntil) {
    if (lockedUntil == _trackedLockedUntil) return;
    _trackedLockedUntil = lockedUntil;
    _tickTimer?.cancel();
    if (lockedUntil == null) return;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (DateTime.now().isAfter(lockedUntil)) {
        t.cancel();
        context.read<LockCubit>().cooldownExpired();
        return;
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = Theme.of(context).textTheme;

    return BlocBuilder<LockCubit, VaultLockState>(
      builder: (context, state) {
        _syncCountdownTimer(state.lockedUntil);
        final cooling = state.isCoolingDown;
        // When biometric isn't available, the password field is the primary
        // affordance, so default it to expanded.
        final showPasswordField = !state.biometricAvailable || _passwordExpanded;

        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Center(child: BrandMark(size: 40)),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'WELCOME BACK',
                        style: AppMono.label(context, size: 11)
                            .copyWith(color: c.fg, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        cooling ? 'Locked out' : 'Locked',
                        style: t.headlineLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        cooling
                            ? 'Too many failed attempts. Wait for the timer to '
                                'expire before trying again.'
                            : state.biometricAvailable
                                ? _bioPrompt(state.biometricKind)
                                : 'Enter your master password to unlock the vault.',
                        textAlign: TextAlign.center,
                        style: t.bodyMedium,
                      ),
                    ),
                    if (cooling) ...[
                      const SizedBox(height: 28),
                      _CountdownPanel(until: state.lockedUntil!),
                    ] else ...[
                      if (state.biometricAvailable && !showPasswordField) ...[
                        const SizedBox(height: 28),
                        _BioRing(
                          kind: state.biometricKind,
                          onTap: state.busy ? null : _doBiometric,
                        ),
                      ],
                      if (showPasswordField) ...[
                        const SizedBox(height: 24),
                        AppField(
                          label: 'Master password',
                          controller: _pwd,
                          obscure: !_showPwd,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          prefixIcon: Icons.key_outlined,
                          suffix: InkWell(
                            onTap: () => setState(() => _showPwd = !_showPwd),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                _showPwd
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 16,
                                color: c.muted,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                    ],
                    if (state.error != null && !cooling) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(text: state.error!),
                    ],
                    const Spacer(),
                    if (cooling)
                      const SizedBox.shrink()
                    else if (showPasswordField)
                      PrimaryActionButton(
                        label: 'Unlock',
                        busy: state.busy,
                        onPressed: _submit,
                      )
                    else
                      GhostActionButton(
                        label: 'Use master password',
                        icon: Icons.lock_outline,
                        onPressed: () =>
                            setState(() => _passwordExpanded = true),
                      ),
                    if (!cooling &&
                        state.biometricAvailable &&
                        showPasswordField) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: state.busy ? null : _doBiometric,
                        icon: Icon(_bioIcon(state.biometricKind), size: 18),
                        label: Text(_bioActionLabel(state.biometricKind)),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BioRing extends StatelessWidget {
  const _BioRing({required this.kind, required this.onTap});
  final BiometricKind kind;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: c.accentSoft,
                shape: BoxShape.circle,
                border: Border.all(color: c.accentLine, width: 1.5),
              ),
              child: Icon(_bioIcon(kind), color: c.accent, size: 38),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _bioRingLabel(kind),
            style: TextStyle(
              color: c.fg,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text('VAULT LOCKED', style: AppMono.label(context, size: 10)),
        ],
      ),
    );
  }
}

IconData _bioIcon(BiometricKind kind) {
  switch (kind) {
    case BiometricKind.face:
      return Icons.face;
    case BiometricKind.fingerprint:
    case BiometricKind.generic:
      return Icons.fingerprint;
  }
}

String _bioPrompt(BiometricKind kind) {
  switch (kind) {
    case BiometricKind.face:
      return 'Use Face ID — or unlock with your master password.';
    case BiometricKind.fingerprint:
    case BiometricKind.generic:
      return 'Touch the sensor — or unlock with your master password.';
  }
}

String _bioRingLabel(BiometricKind kind) {
  switch (kind) {
    case BiometricKind.face:
      return 'Tap to use Face ID';
    case BiometricKind.fingerprint:
    case BiometricKind.generic:
      return 'Touch to unlock';
  }
}

String _bioActionLabel(BiometricKind kind) {
  switch (kind) {
    case BiometricKind.face:
      return 'Use Face ID';
    case BiometricKind.fingerprint:
    case BiometricKind.generic:
      return 'Use biometric';
  }
}

class _CountdownPanel extends StatelessWidget {
  const _CountdownPanel({required this.until});
  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final remaining = until.difference(DateTime.now());
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    return Center(
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: c.errorSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: c.error.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(Icons.lock_clock, color: c.error, size: 38),
          ),
          const SizedBox(height: 16),
          Text(
            _formatRemaining(clamped),
            style: AppMono.of(
              context,
              size: 28,
              color: c.fg,
              letterSpacing: 1.5,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('LOCKED OUT', style: AppMono.label(context, size: 10)),
        ],
      ),
    );
  }
}

String _formatRemaining(Duration d) {
  final totalSeconds = d.inSeconds;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.errorSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.error.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: c.error, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: c.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
