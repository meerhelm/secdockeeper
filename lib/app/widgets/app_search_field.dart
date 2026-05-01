import 'package:flutter/material.dart';

import '../tokens.dart';

/// 44 px tall filled search bar with a 12 px radius. Uses the standard
/// `TextField` underneath but with the design's softer styling.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search, size: 16, color: c.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: TextStyle(color: c.fg, fontSize: 14),
              cursorColor: c.accent,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(color: c.muted, fontSize: 14),
                filled: false,
              ),
            ),
          ),
          if (suffix != null) Padding(
            padding: const EdgeInsets.only(right: 8),
            child: suffix,
          ) else const SizedBox(width: 14),
        ],
      ),
    );
  }
}
