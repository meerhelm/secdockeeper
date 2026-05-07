import 'package:flutter/material.dart';

import '../tokens.dart';

/// Amber left-bordered banner for irreversibility / privacy warnings.
class WarnBanner extends StatelessWidget {
  const WarnBanner({
    super.key,
    required this.title,
    this.body,
    this.icon = Icons.warning_amber_rounded,
  });

  final String title;
  final String? body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 2, color: c.warn),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: c.warn.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 12, color: c.warn),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: c.fg,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                            children: [
                              TextSpan(
                                text: title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (body != null) TextSpan(text: '\n$body'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
