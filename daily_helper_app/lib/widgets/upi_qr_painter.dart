import 'package:flutter/material.dart';

class UpiQrWidget extends StatelessWidget {
  final String data;
  final double size;

  const UpiQrWidget({
    super.key,
    required this.data,
    this.size = 160,
  });

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    final bg = Theme.of(context).colorScheme.surface;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _DeterministicQrPainter(seed: data, color: fg),
      ),
    );
  }
}

class _DeterministicQrPainter extends CustomPainter {
  final String seed;
  final Color color;

  _DeterministicQrPainter({required this.seed, required this.color});

  bool _isFinder(int r, int c, int r0, int c0) {
    final lr = r - r0;
    final lc = c - c0;
    return lr == 0 || lr == 6 || lc == 0 || lc == 6 || (lr >= 2 && lr <= 4 && lc >= 2 && lc <= 4);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const grid = 21;
    final cell = size.width / grid;
    final paint = Paint()..color = color;

    int h = 0x811c9dc5;
    for (int i = 0; i < seed.length; i++) {
      h ^= seed.codeUnitAt(i);
      h = (h * 0x01000193) & 0x7fffffff;
    }

    for (int r = 0; r < grid; r++) {
      for (int c = 0; c < grid; c++) {
        bool on = false;
        if (r < 7 && c < 7) {
          on = _isFinder(r, c, 0, 0);
        } else if (r < 7 && c >= grid - 7) {
          on = _isFinder(r, c, 0, grid - 7);
        } else if (r >= grid - 7 && c < 7) {
          on = _isFinder(r, c, grid - 7, 0);
        } else {
          h ^= (r * 31 + c * 17);
          h = (h * 0x01000193) & 0x7fffffff;
          on = (h % 10) < 5;
        }
        if (on) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DeterministicQrPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.color != color;
}
