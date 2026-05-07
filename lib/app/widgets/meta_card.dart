import 'package:flutter/material.dart';

import '../tokens.dart';

/// Card with a vertical list of `KEY · value` rows separated by 1px lines.
/// Used on the document detail screen for properties.
class MetaCard extends StatelessWidget {
  const MetaCard({super.key, required this.rows});
  final List<MetaRow> rows;

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
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i != 0) Divider(height: 1, color: c.border),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class MetaRow extends StatelessWidget {
  const MetaRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = true,
    this.trailing,
  });

  final String label;
  final String value;
  final bool mono;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(label.toUpperCase(), style: AppMono.label(context)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: trailing ??
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: mono
                      ? AppMono.of(context, size: 12.5, color: c.fg)
                      : TextStyle(fontSize: 14, color: c.fg),
                ),
          ),
        ],
      ),
    );
  }
}

/// Pill used inside a [MetaRow] trailing slot — accent-soft with leading dot.
class MetaPill extends StatelessWidget {
  const MetaPill(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppMono.of(
              context,
              size: 10.5,
              color: c.accent,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
