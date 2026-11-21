import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/vault_storage.dart';
import '../widgets/upi_qr_painter.dart';

class UpiSettleScreen extends StatefulWidget {
  final BookingRecord booking;

  const UpiSettleScreen({
    super.key,
    required this.booking,
  });

  @override
  State<UpiSettleScreen> createState() => _UpiSettleScreenState();
}

class _UpiSettleScreenState extends State<UpiSettleScreen> {
  late TextEditingController _amountCtrl;
  String _method = 'UPI';

  @override
  void initState() {
    super.initState();
    final initial = widget.booking.visitFeeInr > 350 ? widget.booking.visitFeeInr : 350;
    _amountCtrl = TextEditingController(text: initial.toString());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final amt = int.tryParse(_amountCtrl.text.trim()) ?? widget.booking.visitFeeInr;
    await VaultStorage.instance.updateJobStatus(
      widget.booking.id,
      'completed',
      finalAmountInr: amt,
      paymentMethod: _method,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pro = VaultStorage.instance.currentProfessionalProfile;
    final theme = Theme.of(context);
    final amountText = _amountCtrl.text.trim().isEmpty ? '0' : _amountCtrl.text.trim();
    final upiPayload = 'upi://pay?pa=${pro.upiId}&am=$amountText&cu=INR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collect Payment'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              key: const Key('settle_amount_field'),
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Final Agreed Amount (₹)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    key: const Key('settle_method_upi_chip'),
                    label: const Center(child: Text('UPI QR')),
                    selected: _method == 'UPI',
                    onSelected: (_) => setState(() => _method = 'UPI'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    key: const Key('settle_method_cash_chip'),
                    label: const Center(child: Text('Cash')),
                    selected: _method == 'Cash',
                    onSelected: (_) => setState(() => _method = 'Cash'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_method == 'UPI') ...[
              Center(child: UpiQrWidget(data: upiPayload, size: 156)),
              const SizedBox(height: 10),
              Text(
                pro.upiId,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '100% direct to your bank · 0% commission',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(
                  'Collect ₹$amountText in cash directly from ${widget.booking.customerName}.',
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 24),
            FilledButton(
              key: const Key('confirm_payment_received_btn'),
              onPressed: _complete,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Payment Received · Complete Job'),
            ),
          ],
        ),
      ),
    );
  }
}
