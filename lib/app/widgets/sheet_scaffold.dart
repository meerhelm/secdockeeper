import 'package:flutter/material.dart';

import '../tokens.dart';

/// Standard layout for a modal bottom sheet — a head row with optional
/// leading icon and trailing widget, the supplied [body], and an optional
/// foot. Drag handle is provided by the bottom-sheet theme.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.body,
    this.headIcon,
    this.headTrailing,
    this.foot,
  });

  final String title;
  final Widget body;
  final IconData? headIcon;
  final Widget? headTrailing;
  final Widget? foot;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  if (headIcon != null) ...[
                    Icon(headIcon, size: 18, color: c.fg),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ?headTrailing,
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: body,
              ),
            ),
            if (foot != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: foot!,
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// "Done" trailing affordance in mono accent — used in tag picker, hidden
/// tags, filter sheets.
class SheetDoneButton extends StatelessWidget {
  const SheetDoneButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        foregroundColor: c.accent,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: const Text('Done'),
    );
  }
}
