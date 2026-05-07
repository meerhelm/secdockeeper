import 'package:flutter/material.dart';

import '../tokens.dart';

/// Three rounded blocks stacked — the SecDockKeeper brand mark.
/// Read it as the cross-section of an encrypted file: a visible payload, a
/// derived middle layer, and a final HMAC tag block at the top, picked out
/// in the brand accent.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 24, this.tile = false});

  /// Outer size in logical pixels. The inner geometry scales linearly.
  final double size;

  /// When true, draws a rounded card behind the blocks (used at 72 px on
  /// onboarding and the lock screen).
  final bool tile;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = size / 24;
    return SizedBox(
      width: size,
      height: size,
      child: tile
          ? Container(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border, width: 1),
                borderRadius: BorderRadius.circular(16 * s),
              ),
              padding: EdgeInsets.symmetric(horizontal: 4 * s, vertical: 4 * s),
              child: _Blocks(scale: s, c: c, embedded: true),
            )
          : _Blocks(scale: s, c: c, embedded: false),
    );
  }
}

class _Blocks extends StatelessWidget {
  const _Blocks({required this.scale, required this.c, required this.embedded});
  final double scale;
  final AppColors c;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // Geometry mirrors the SVG in design/redesign-v1.html.
    // Three blocks of height 4, gaps of 2 between, centred horizontally.
    // Outer canvas is 24×24 (un-scaled); when embedded inside the tile we
    // use the inner area, so the blocks shift slightly.
    final h = 4.0 * scale;
    final r = 1.4 * scale;
    final wTop = 8.0 * scale;
    final wMid = 16.0 * scale;
    final wBot = 20.0 * scale;
    final gap = 2.0 * scale;
    final radius = BorderRadius.circular(r);

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: wTop,
              height: h,
              decoration: BoxDecoration(color: c.accent, borderRadius: radius),
            ),
            SizedBox(height: gap),
            Container(
              width: wMid,
              height: h,
              decoration: BoxDecoration(color: c.fg, borderRadius: radius),
            ),
            SizedBox(height: gap),
            Container(
              width: wBot,
              height: h,
              decoration: BoxDecoration(color: c.fg, borderRadius: radius),
            ),
          ],
        ),
      ),
    );
  }
}
