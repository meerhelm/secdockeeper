import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/tokens.dart';
import '../../app/widgets/app_buttons.dart';
import '../../app/widgets/app_field.dart';
import '../../app/widgets/brand_mark.dart';
import '../../app/widgets/warn_banner.dart';
import 'cubit/onboarding_cubit.dart';
import 'cubit/onboarding_state.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPwd = false;
  bool _showConfirm = false;
  int _strength = 0;

  @override
  void initState() {
    super.initState();
    _pwd.addListener(_recomputeStrength);
  }

  @override
  void dispose() {
    _pwd.removeListener(_recomputeStrength);
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _recomputeStrength() {
    final v = _pwd.text;
    var s = 0;
    if (v.length >= 8) s++;
    if (v.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v)) s++;
    if (RegExp(r'\d').hasMatch(v) || RegExp(r'[^A-Za-z0-9]').hasMatch(v)) s++;
    if (s != _strength) setState(() => _strength = s);
  }

  String get _strengthLabel => switch (_strength) {
        0 => 'too short',
        1 => 'weak',
        2 => 'fair',
        3 => 'good',
        _ => 'strong',
      };

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<OnboardingCubit>().create(_pwd.text);
  }

  Future<void> _restore() async {
    final cubit = context.read<OnboardingCubit>();
    final pick = await FilePicker.pickFiles(
      dialogTitle: 'Pick backup .zip',
      type: FileType.any,
    );
    if (pick == null || pick.files.isEmpty) return;
    final path = pick.files.single.path;
    if (path == null) return;
    await cubit.restore(File(path));
  }

  Future<void> _onAskBiometric() async {
    final cubit = context.read<OnboardingCubit>();
    final c = context.c;
    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 4),
        contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.fingerprint, size: 26, color: c.accent),
            ),
            const SizedBox(height: 14),
            const Text('Enable biometric unlock?'),
          ],
        ),
        content: Text(
          'Use fingerprint or Face ID to quickly unlock the vault. Your master '
          'password is wrapped by the device secure enclave — it never leaves '
          'it, and we never see it.',
          style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: c.fg),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    await cubit.resolveBiometric(accepted: accept ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = Theme.of(context).textTheme;
    final messenger = ScaffoldMessenger.of(context);

    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listenWhen: (prev, curr) =>
          prev.askBiometric != curr.askBiometric ||
          prev.restoreMessage != curr.restoreMessage,
      listener: (context, state) {
        if (state.askBiometric) _onAskBiometric();
        final msg = state.restoreMessage;
        if (msg != null) {
          messenger.showSnackBar(SnackBar(content: Text(msg)));
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Center(child: BrandMark(size: 72, tile: true)),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            'SECDOCKKEEPER',
                            style: AppMono.label(context, size: 11)
                                .copyWith(color: c.fg, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Create your vault', style: t.headlineLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a master password. It encrypts every document and tag locally.',
                          style: t.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        const WarnBanner(
                          title: 'There is no recovery if forgotten.',
                          body: 'No email reset, no security questions, no support backdoor — by design.',
                        ),
                        const SizedBox(height: 24),
                        AppField(
                          label: 'Master password',
                          controller: _pwd,
                          obscure: !_showPwd,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.lock_outline,
                          suffix: _EyeToggle(
                            shown: _showPwd,
                            onTap: () => setState(() => _showPwd = !_showPwd),
                          ),
                          validator: (v) {
                            if (v == null || v.length < 8) {
                              return 'At least 8 characters';
                            }
                            return null;
                          },
                        ),
                        AppStrengthMeter(
                          score: _strength,
                          leftLabel: 'STRENGTH · $_strengthLabel',
                          rightLabel: '${_pwd.text.length} CHARS',
                        ),
                        const SizedBox(height: 16),
                        AppField(
                          label: 'Confirm password',
                          controller: _confirm,
                          obscure: !_showConfirm,
                          textInputAction: TextInputAction.done,
                          prefixIcon: Icons.lock_outline,
                          suffix: _EyeToggle(
                            shown: _showConfirm,
                            onTap: () =>
                                setState(() => _showConfirm = !_showConfirm),
                          ),
                          onSubmitted: (_) => _submit(),
                          validator: (v) {
                            if (v != _pwd.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        if (state.error != null) ...[
                          const SizedBox(height: 16),
                          _ErrorBanner(text: state.error!),
                        ],
                        const SizedBox(height: 24),
                        PrimaryActionButton(
                          label: 'Create vault',
                          busy: state.busy,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 20),
                        const OrDivider(),
                        const SizedBox(height: 20),
                        OutlineActionButton(
                          label: 'Restore from backup',
                          icon: Icons.download,
                          onPressed: state.busy ? null : _restore,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.shown, required this.onTap});
  final bool shown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 16,
          color: c.muted,
        ),
      ),
    );
  }
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
