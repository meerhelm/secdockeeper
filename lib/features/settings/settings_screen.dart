import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/tokens.dart';
import '../../app/widgets/row_tile.dart';
import '../../app/widgets/section_label.dart';
import '../../core/crypto/kdf.dart';
import '../security/lock_settings.dart';
import '../vault/widgets/change_master_password_dialog.dart';
import '../vault/widgets/destroy_vault_dialog.dart';
import 'cubit/settings_cubit.dart';
import 'cubit/settings_state.dart';

const _autoLockOptions = <int>[0, 30, 60, 300, 900];

String _autoLockLabel(int seconds) => switch (seconds) {
      0 => 'Immediate',
      30 => '30 seconds',
      60 => '1 minute',
      300 => '5 minutes',
      900 => '15 minutes',
      _ => '$seconds seconds',
    };

String _themeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'Match system',
    };

String _kdfLabel(KdfProfile profile) => switch (profile) {
      KdfProfile.standard => 'Standard',
      KdfProfile.hardened => 'Hardened',
    };

String _kdfSubtitle(KdfProfile profile) => switch (profile) {
      KdfProfile.standard =>
        '64 MiB · 3 iterations — OWASP recommended baseline.',
      KdfProfile.hardened =>
        '128 MiB · 4 iterations — noticeably slower unlock.',
    };

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _importShared(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final blobPick = await FilePicker.pickFiles(
      dialogTitle: 'Pick the .sdkblob file',
      type: FileType.any,
    );
    if (blobPick == null || blobPick.files.isEmpty) return;
    final blobPath = blobPick.files.single.path;
    if (blobPath == null) return;

    if (!context.mounted) return;
    final keyPick = await FilePicker.pickFiles(
      dialogTitle: 'Pick the matching .sdkkey.json file',
      type: FileType.any,
    );
    if (keyPick == null || keyPick.files.isEmpty) return;
    final keyPath = keyPick.files.single.path;
    if (keyPath == null) return;

    await cubit.importSharedPackage(
      blobFile: File(blobPath),
      keyFile: File(keyPath),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (ctx) => const ChangeMasterPasswordDialog(),
    );
    if (newPassword != null) {
      await cubit.changeMasterPassword(newPassword);
    }
  }

  Future<void> _toggleBiometric(BuildContext context, bool turnOn) async {
    final cubit = context.read<SettingsCubit>();
    if (!turnOn) {
      await cubit.disableBiometric();
      return;
    }
    final password = await _promptMasterPassword(context);
    if (password == null || password.isEmpty) return;
    await cubit.enableBiometric(password);
  }

  Future<String?> _promptMasterPassword(
    BuildContext context, {
    String description =
        'Enter your master password to enable biometric login. '
            'It is stored in the device keystore and never leaves this device.',
    String confirmLabel = 'Enable',
  }) async {
    final c = context.c;
    final ctl = TextEditingController();
    var obscure = true;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Confirm master password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: TextStyle(color: c.muted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctl,
                autofocus: true,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Master password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    onPressed: () => setSt(() => obscure = !obscure),
                  ),
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: c.fg),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAutoLock(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final current = cubit.state.autoLockSeconds;
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => _PickerSheet<int>(
        title: 'Auto-lock',
        description:
            'How long the vault stays unlocked while the app is in the '
            'background.',
        options: _autoLockOptions,
        current: current,
        labelOf: _autoLockLabel,
      ),
    );
    if (picked != null) {
      await cubit.setAutoLockSeconds(picked);
    }
  }

  Future<void> _pickTheme(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (ctx) => _PickerSheet<ThemeMode>(
        title: 'Theme',
        description: 'Light, dark, or match the device setting.',
        options: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
        current: cubit.state.themeMode,
        labelOf: _themeLabel,
      ),
    );
    if (picked != null) {
      await cubit.setThemeMode(picked);
    }
  }

  Future<void> _pickKdfProfile(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final current = cubit.state.kdfProfile;
    final picked = await showModalBottomSheet<KdfProfile>(
      context: context,
      builder: (ctx) => _PickerSheet<KdfProfile>(
        title: 'Argon2id profile',
        description:
            'Controls how much work each unlock costs. Hardened is stronger '
            'but adds a few seconds per unlock.',
        options: KdfProfile.values,
        current: current,
        labelOf: _kdfLabel,
        descriptionOf: _kdfSubtitle,
      ),
    );
    if (picked == null || picked == current) return;
    if (!context.mounted) return;
    if (picked == KdfProfile.standard) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Argon2id downgrade is not supported.')),
      );
      return;
    }
    await _runHarden(context, target: picked, params: picked.params);
  }

  Future<void> _runHarden(
    BuildContext context, {
    required KdfProfile target,
    required KdfParams params,
  }) async {
    final cubit = context.read<SettingsCubit>();
    final confirmed = await _confirmHarden(context, target);
    if (confirmed != true) return;
    if (!context.mounted) return;

    final stored = await cubit.readStoredMasterPassword();
    String? password = stored;
    if (password == null) {
      if (!context.mounted) return;
      password = await _promptMasterPassword(
        context,
        description:
            'Re-keys the vault under the new Argon2id parameters. The '
            'password itself does not change.',
        confirmLabel: 'Harden',
      );
    }
    if (password == null || password.isEmpty) return;
    if (!context.mounted) return;

    final progressFuture = cubit.hardenTo(
      targetParams: params,
      currentPassword: password,
    );
    await _showHardeningProgress(context, progressFuture);
  }

  Future<bool?> _confirmHarden(BuildContext context, KdfProfile target) async {
    final c = context.c;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Harden vault?'),
        content: Text(
          'Re-derives the master key under ${_kdfLabel(target)} Argon2id '
          'parameters and re-encrypts every wrapped key. Each unlock will '
          'take a few extra seconds afterwards. Do not close the app while '
          'this runs.',
          style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: c.fg),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Harden'),
          ),
        ],
      ),
    );
  }

  Future<void> _showHardeningProgress(
    BuildContext context,
    Future<bool> task,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text('Hardening vault — keep the app open.'),
              ),
            ],
          ),
        ),
      ),
    );
    try {
      await task;
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _destroyVault(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const DestroyVaultDialog(),
    );
    if (confirmed == true) {
      await cubit.destroyVault();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final messenger = ScaffoldMessenger.of(context);

    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (a, b) =>
          a.message != b.message || a.error != b.error,
      listener: (context, state) {
        if (state.message != null) {
          messenger.showSnackBar(SnackBar(content: Text(state.message!)));
        }
        if (state.error != null) {
          messenger.showSnackBar(SnackBar(
            content: Text(state.error!),
            backgroundColor: c.errorSoft,
          ));
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(
            backgroundColor: c.bg,
            elevation: 0,
            title: Text('Settings', style: TextStyle(color: c.fg)),
            iconTheme: IconThemeData(color: c.fg),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              children: [
                if (state.kdfBelowDefault)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: _HardenBanner(
                      busy: state.busy,
                      onTap: () => _runHarden(
                        context,
                        target: KdfProfile.standard,
                        params: KdfParams.defaultParams,
                      ),
                    ),
                  ),
                const SectionLabel('Vault'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RowTileGroup(
                    children: [
                      RowTile(
                        icon: Icons.upload_outlined,
                        title: 'Import shared package',
                        subtitle: '.sdkblob + .sdkkey.json',
                        onTap: state.busy
                            ? null
                            : () => _importShared(context),
                      ),
                      RowTile(
                        icon: Icons.download_outlined,
                        title: 'Export full backup',
                        subtitle:
                            'Encrypted .zip · password-protected',
                        onTap: state.busy
                            ? null
                            : () => context
                                .read<SettingsCubit>()
                                .exportBackup(),
                      ),
                      RowTile(
                        icon: Icons.key_outlined,
                        title: 'Change master password',
                        subtitle: 'Re-encrypts every document and note key',
                        onTap: state.busy
                            ? null
                            : () => _changePassword(context),
                      ),
                    ],
                  ),
                ),
                const SectionLabel('Security'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RowTileGroup(
                    children: [
                      _BiometricRow(
                        enabled: state.biometricEnabled,
                        available: state.biometricAvailable,
                        busy: state.busy,
                        onChanged: (v) => _toggleBiometric(context, v),
                      ),
                      RowTile(
                        icon: Icons.timer_outlined,
                        title: 'Auto-lock',
                        subtitle: _autoLockLabel(state.autoLockSeconds),
                        onTap: state.busy ? null : () => _pickAutoLock(context),
                      ),
                    ],
                  ),
                ),
                const SectionLabel('Encryption'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RowTileGroup(
                    children: [
                      RowTile(
                        icon: Icons.shield_outlined,
                        title: 'Argon2id profile',
                        subtitle:
                            '${_kdfLabel(state.kdfProfile)} · '
                            '${_kdfSubtitle(state.kdfProfile)}',
                        onTap: state.busy
                            ? null
                            : () => _pickKdfProfile(context),
                      ),
                    ],
                  ),
                ),
                const SectionLabel('Appearance'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RowTileGroup(
                    children: [
                      RowTile(
                        icon: Icons.brightness_6_outlined,
                        title: 'Theme',
                        subtitle: _themeLabel(state.themeMode),
                        onTap: state.busy ? null : () => _pickTheme(context),
                      ),
                    ],
                  ),
                ),
                const SectionLabel('Panic mode'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Decide what happens after 3 wrong password attempts.',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PanicChoiceTile(
                        icon: Icons.lock_clock,
                        title: 'Lock for 10 minutes',
                        subtitle:
                            'Cooldown grows on repeat: 10 m → 30 m → 1 h → 1 day. '
                            'Counter resets only on a successful unlock.',
                        selected: state.panicAction == PanicAction.lockout,
                        onTap: state.busy
                            ? null
                            : () => context
                                .read<SettingsCubit>()
                                .setPanicAction(PanicAction.lockout),
                      ),
                      const SizedBox(height: 10),
                      _PanicChoiceTile(
                        icon: Icons.delete_forever_outlined,
                        title: 'Wipe vault permanently',
                        subtitle:
                            'On the 3rd wrong attempt every document, key, and tag '
                            'is deleted. No recovery without a backup.',
                        danger: true,
                        selected: state.panicAction == PanicAction.wipe,
                        onTap: state.busy
                            ? null
                            : () => _onPickWipe(context),
                      ),
                    ],
                  ),
                ),
                const SectionLabel('Danger zone'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RowTileGroup(
                    children: [
                      _DangerTile(
                        icon: Icons.delete_forever_outlined,
                        title: 'Destroy vault',
                        subtitle:
                            'Wipes every document and note — irreversible.',
                        onTap: state.busy
                            ? null
                            : () => _destroyVault(context),
                      ),
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

  Future<void> _onPickWipe(BuildContext ctx) async {
    final cubit = ctx.read<SettingsCubit>();
    if (cubit.state.panicAction == PanicAction.wipe) return;
    final c = ctx.c;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text('Enable wipe-on-panic?', style: TextStyle(color: c.error)),
        content: const Text(
          'After 3 wrong password attempts your vault will be permanently '
          'erased — no warning, no undo. Are you sure?',
          style: TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            style: TextButton.styleFrom(foregroundColor: c.fg),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: c.error,
              foregroundColor: c.fgStrong,
            ),
            child: const Text('Enable wipe'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await cubit.setPanicAction(PanicAction.wipe);
    }
  }
}

class _BiometricRow extends StatelessWidget {
  const _BiometricRow({
    required this.enabled,
    required this.available,
    required this.busy,
    required this.onChanged,
  });

  final bool enabled;
  final bool available;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final canToggle = available && !busy;
    final subtitle = !available
        ? 'Not available on this device'
        : enabled
            ? 'Unlock with biometrics; master password kept in the device keystore.'
            : 'Off — every unlock requires the master password.';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.fingerprint, size: 18, color: c.fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Biometric login',
                  style: TextStyle(
                    color: c.fg,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.07,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: enabled,
            onChanged: canToggle ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _DangerTile extends StatelessWidget {
  const _DangerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.errorSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: c.error),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: c.error,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.07,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: c.muted2),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.description,
    required this.options,
    required this.current,
    required this.labelOf,
    this.descriptionOf,
  });

  final String title;
  final String description;
  final List<T> options;
  final T current;
  final String Function(T) labelOf;
  final String Function(T)? descriptionOf;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: c.fg,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(color: c.muted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 14),
            for (final option in options)
              _PickerRow<T>(
                label: labelOf(option),
                description: descriptionOf?.call(option),
                selected: option == current,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow<T> extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
  });

  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? c.accent : c.muted2,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: c.fg,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.07,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanicChoiceTile extends StatelessWidget {
  const _PanicChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final accent = danger ? c.error : c.accent;
    final borderColor = selected ? accent : c.border;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? (danger ? c.errorSoft : c.accentSoft)
              : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: danger ? c.error : c.fg,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle, size: 18, color: accent),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: c.muted,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HardenBanner extends StatelessWidget {
  const _HardenBanner({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.accentSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.accentLine, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_moon_outlined, size: 22, color: c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vault below current security profile',
                      style: TextStyle(
                        color: c.fg,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.07,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This vault was created with older Argon2id parameters. '
                      'Tap to re-key under the current defaults — adds a few '
                      'seconds to each unlock.',
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: c.muted2),
            ],
          ),
        ),
      ),
    );
  }
}
