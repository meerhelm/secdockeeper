import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/tokens.dart';
import '../security/lock_settings.dart';
import 'cubit/settings_cubit.dart';
import 'cubit/settings_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final messenger = ScaffoldMessenger.of(context);

    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (a, b) => a.message != b.message && b.message != null,
      listener: (context, state) {
        messenger.showSnackBar(SnackBar(content: Text(state.message!)));
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
              padding: const EdgeInsets.all(16),
              children: [
                Text('PANIC MODE', style: AppMono.label(context, size: 11)),
                const SizedBox(height: 10),
                Text(
                  'Decide what happens after 3 wrong password attempts.',
                  style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.5),
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
