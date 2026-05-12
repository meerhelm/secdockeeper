import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/tokens.dart';
import '../../app/widgets/row_tile.dart';
import '../../app/widgets/section_label.dart';
import '../security/lock_settings.dart';
import '../vault/widgets/change_master_password_dialog.dart';
import '../vault/widgets/destroy_vault_dialog.dart';
import 'cubit/settings_cubit.dart';
import 'cubit/settings_state.dart';

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

  Future<String?> _promptMasterPassword(BuildContext context) async {
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
                'Enter your master password to enable biometric login. '
                'It is stored in the device keystore and never leaves this device.',
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
              child: const Text('Enable'),
            ),
          ],
        ),
      ),
    );
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
