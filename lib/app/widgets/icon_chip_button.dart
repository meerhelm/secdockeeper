import 'package:flutter/material.dart';

import '../tokens.dart';

/// 36×36 squared icon button with a 10px radius and a 1px border.
/// `ghost: true` removes the border + fill so the button only shows the icon.
class IconChipButton extends StatelessWidget {
  const IconChipButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.ghost = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final btn = Material(
      color: ghost ? Colors.transparent : c.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: ghost ? null : Border.all(color: c.border, width: 1),
          ),
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: c.fg),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}
