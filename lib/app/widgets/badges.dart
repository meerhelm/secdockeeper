import 'package:flutter/material.dart';

import '../tokens.dart';

/// Compact "Passport" / "Receipt" classification badge — accent-soft pill
/// with a leading dot in the accent colour.
class ClassBadge extends StatelessWidget {
  const ClassBadge(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppMono.of(
              context,
              size: 10,
              color: c.accent,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny `#tag-name` mono pill used inside document cards alongside class
/// badges. Visually subordinate.
class TagMini extends StatelessWidget {
  const TagMini(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          label.startsWith('#') ? label : '#$label',
          style: AppMono.of(
            context,
            size: 10,
            color: c.muted,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Larger accent-soft chip used inside the document detail tags card.
/// Includes an optional close icon for unassigning.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.onDeleted});

  final String label;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 26,
      padding: EdgeInsets.fromLTRB(8, 0, onDeleted != null ? 4 : 8, 0),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.startsWith('#') ? label : '#$label',
            style: TextStyle(
              color: c.accent,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onDeleted != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onDeleted,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: 11, color: c.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
