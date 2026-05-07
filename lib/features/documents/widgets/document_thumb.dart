import 'package:flutter/material.dart';

import '../../../app/tokens.dart';

/// 56×56 placeholder thumbnail driven by MIME type. Produces a gradient for
/// images, a striped page motif for PDFs, and a tinted icon for everything
/// else. Real decrypted previews can replace this in a future pass.
class DocumentThumb extends StatelessWidget {
  const DocumentThumb({super.key, required this.mime, this.uuid, this.size = 56});

  final String? mime;
  final String? uuid;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final radius = BorderRadius.circular(size * 0.18);

    final type = _classify(mime);
    switch (type) {
      case _ThumbType.image:
        return _GradientThumb(size: size, radius: radius, palette: _imagePalette(uuid));
      case _ThumbType.pdf:
        return _PdfPagedThumb(size: size, radius: radius);
      case _ThumbType.text:
        return _IconThumb(
          size: size,
          radius: radius,
          color: c.surface2,
          iconColor: c.fg,
          icon: Icons.text_snippet_outlined,
        );
      case _ThumbType.video:
        return _IconThumb(
          size: size,
          radius: radius,
          color: c.surface2,
          iconColor: c.fg,
          icon: Icons.movie_outlined,
        );
      case _ThumbType.audio:
        return _IconThumb(
          size: size,
          radius: radius,
          color: c.surface2,
          iconColor: c.fg,
          icon: Icons.music_note_outlined,
        );
      case _ThumbType.misc:
        return _IconThumb(
          size: size,
          radius: radius,
          color: c.surface2,
          iconColor: c.fg,
          icon: Icons.description_outlined,
        );
    }
  }

  static _ThumbType _classify(String? mime) {
    if (mime == null) return _ThumbType.misc;
    if (mime.startsWith('image/')) return _ThumbType.image;
    if (mime == 'application/pdf') return _ThumbType.pdf;
    if (mime.startsWith('text/')) return _ThumbType.text;
    if (mime.startsWith('video/')) return _ThumbType.video;
    if (mime.startsWith('audio/')) return _ThumbType.audio;
    return _ThumbType.misc;
  }

  static List<Color> _imagePalette(String? uuid) {
    const palettes = <List<Color>>[
      [Color(0xFF3A2A4A), Color(0xFF6E4A72), Color(0xFFC08A8A)],
      [Color(0xFF1F3340), Color(0xFF38667A), Color(0xFF6DA3B8)],
      [Color(0xFF2A3A2A), Color(0xFF4D6E4A), Color(0xFFA4C69A)],
    ];
    if (uuid == null || uuid.isEmpty) return palettes[0];
    return palettes[uuid.hashCode.abs() % palettes.length];
  }
}

enum _ThumbType { image, pdf, text, video, audio, misc }

class _GradientThumb extends StatelessWidget {
  const _GradientThumb({required this.size, required this.radius, required this.palette});
  final double size;
  final BorderRadius radius;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.7, -0.9),
          end: const Alignment(0.9, 0.9),
          colors: palette,
          stops: const [0, 0.6, 1],
        ),
        borderRadius: radius,
      ),
    );
  }
}

class _PdfPagedThumb extends StatelessWidget {
  const _PdfPagedThumb({required this.size, required this.radius});
  final double size;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFF7EFE2),
        child: CustomPaint(
          painter: _PdfLinesPainter(
            line: isLight ? const Color(0xFF2A2A2C) : const Color(0xFFB39577),
            opacity: isLight ? 0.5 : 0.7,
          ),
        ),
      ),
    );
  }
}

class _PdfLinesPainter extends CustomPainter {
  _PdfLinesPainter({required this.line, required this.opacity});
  final Color line;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line.withValues(alpha: opacity)
      ..strokeWidth = 1;
    const step = 8.0;
    final inset = size.width * 0.18;
    for (var y = step; y < size.height - 4; y += step) {
      canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), paint);
    }
  }

  @override
  bool shouldRepaint(_PdfLinesPainter old) =>
      old.line != line || old.opacity != opacity;
}

class _IconThumb extends StatelessWidget {
  const _IconThumb({
    required this.size,
    required this.radius,
    required this.color,
    required this.iconColor,
    required this.icon,
  });
  final double size;
  final BorderRadius radius;
  final Color color;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: radius),
      child: Icon(icon, size: size * 0.42, color: iconColor),
    );
  }
}
