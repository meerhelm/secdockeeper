import 'package:flutter/material.dart';

import '../tokens.dart';

/// Mono uppercase section header, used above meta cards / row tiles / etc.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(24, 22, 24, 8),
      child: Text(text.toUpperCase(), style: AppMono.label(context)),
    );
  }
}
