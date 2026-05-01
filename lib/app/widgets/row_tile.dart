import 'package:flutter/material.dart';

import '../tokens.dart';

/// Card-shaped row with a 40 px icon, a title + optional sub, and a chevron.
/// Used for the folder block on document detail and inside action cards.
class RowTile extends StatelessWidget {
  const RowTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.accentIcon = false,
    this.primary = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool accentIcon;
  final bool primary;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final iconBg = primary
        ? c.accent
        : accentIcon
            ? c.accentSoft
            : c.surface2;
    final iconColor = primary
        ? c.accentFg
        : accentIcon
            ? c.accent
            : c.fg;
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: c.fg,
                        fontSize: 14.5,
                        fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
                        letterSpacing: -0.07,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                Icon(Icons.chevron_right, size: 18, color: c.muted2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standalone card-wrapped row tile. Use this for one-off rows; use a
/// [RowTileGroup] when you want several stacked together with dividers.
class RowTileCard extends StatelessWidget {
  const RowTileCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.accentIcon = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool accentIcon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: RowTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
        accentIcon: accentIcon,
        trailing: trailing,
      ),
    );
  }
}

/// Vertical group of RowTiles inside a single bordered card with 1px
/// dividers between rows.
class RowTileGroup extends StatelessWidget {
  const RowTileGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i != 0) Divider(height: 1, color: c.border),
            children[i],
          ],
        ],
      ),
    );
  }
}
