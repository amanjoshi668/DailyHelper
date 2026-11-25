import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Renders a real ISO/IEC 18004 scannable QR code (compatible with PhonePe, GPay, Paytm, BHIM)
/// on a high-contrast white quiet zone so it scans reliably in both light and dark modes.
class UpiQrWidget extends StatelessWidget {
  final String data;
  final double size;

  const UpiQrWidget({
    super.key,
    required this.data,
    this.size = 168,
  });

  @override
  Widget build(BuildContext context) {
    final safeData = data.trim().isEmpty ? 'upi://pay?pa=dailyhelper@upi&cu=INR' : data.trim();
    final qrCode = QrCode.fromData(
      data: safeData,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _RealQrPainter(qrImage: qrImage),
      ),
    );
  }
}

class _RealQrPainter extends CustomPainter {
  final QrImage qrImage;

  _RealQrPainter({required this.qrImage});

  @override
  void paint(Canvas canvas, Size size) {
    final count = qrImage.moduleCount;
    if (count <= 0) return;

    final moduleSize = size.width / count;
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (int y = 0; y < count; y++) {
      for (int x = 0; x < count; x++) {
        if (qrImage.isDark(y, x)) {
          canvas.drawRect(
            Rect.fromLTWH(
              x * moduleSize,
              y * moduleSize,
              moduleSize + 0.25,
              moduleSize + 0.25,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RealQrPainter oldDelegate) =>
      oldDelegate.qrImage.moduleCount != qrImage.moduleCount;
}
